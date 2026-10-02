//! Typed host values: what WinMux sends as JSON and the helper hands to Nickel.
//!
//! Nickel's contracts are lazy, so a record missing a field would only fail when a function body
//! reads it. Every host value therefore goes through a Rust type first: deserialising rejects a
//! missing field before any Nickel runs, and the type says which strings are enum tags.

use nickel_lang_core::{
    eval::value::{Array, NickelValue},
    identifier::{Ident, LocIdent},
    term::{Number, Term, record::RecordData},
};

/// The shape of a host type, for generating Nickel contracts and `config schema` output.
#[derive(Debug, Clone, PartialEq)]
pub enum Shape {
    String,
    Bool,
    Number,
    Enum(&'static [&'static str]),
    Array(Box<Shape>),
    Nullable(Box<Shape>),
    Record { name: &'static str, fields: Vec<Field> },
}

/// One field of a host record: its name on the wire and in Nickel, and what `config schema`
/// says about it.
#[derive(Debug, Clone, PartialEq)]
pub struct Field {
    pub name: &'static str,
    pub shape: Shape,
    pub description: &'static str,
}

pub trait HostValue: serde::de::DeserializeOwned {
    fn shape() -> Shape;
    fn to_nickel(&self) -> NickelValue;
    /// A fully populated value for the load-time smoke run.
    fn synthetic() -> Self;
}

impl HostValue for String {
    fn shape() -> Shape {
        Shape::String
    }
    fn to_nickel(&self) -> NickelValue {
        NickelValue::string_posless(self.as_str())
    }
    fn synthetic() -> Self {
        // Implausible on purpose: a Filter that compares against it takes its "no" branch.
        "winmux-smoke".to_owned()
    }
}

impl HostValue for bool {
    fn shape() -> Shape {
        Shape::Bool
    }
    fn to_nickel(&self) -> NickelValue {
        NickelValue::bool_value_posless(*self)
    }
    fn synthetic() -> Self {
        true
    }
}

impl HostValue for i64 {
    fn shape() -> Shape {
        Shape::Number
    }
    fn to_nickel(&self) -> NickelValue {
        NickelValue::number_posless(*self)
    }
    fn synthetic() -> Self {
        1
    }
}

impl HostValue for f64 {
    fn shape() -> Shape {
        Shape::Number
    }
    fn to_nickel(&self) -> NickelValue {
        // Nickel numbers are exact rationals. JSON cannot carry NaN or an infinity, so the
        // conversion only fails for a value WinMux could not have sent.
        NickelValue::number_posless(Number::try_from(*self).unwrap_or_default())
    }
    fn synthetic() -> Self {
        1.0
    }
}

impl<T: HostValue> HostValue for Vec<T> {
    fn shape() -> Shape {
        Shape::Array(Box::new(T::shape()))
    }
    fn to_nickel(&self) -> NickelValue {
        container(NickelValue::array_posless(self.iter().map(T::to_nickel).collect::<Array>(), Vec::new()))
    }
    fn synthetic() -> Self {
        vec![T::synthetic()]
    }
}

/// A value that may be `null`. Unlike `Option`, which serde fills in when a field is absent, the
/// field itself must be on the wire.
#[derive(Debug, Clone)]
pub struct Nullable<T>(pub Option<T>);

impl<'de, T: serde::de::DeserializeOwned> serde::Deserialize<'de> for Nullable<T> {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let value = serde_json::Value::deserialize(deserializer)?;
        if value.is_null() {
            return Ok(Nullable(None));
        }
        serde_json::from_value(value).map(|value| Nullable(Some(value))).map_err(serde::de::Error::custom)
    }
}

impl<T: HostValue> HostValue for Nullable<T> {
    fn shape() -> Shape {
        Shape::Nullable(Box::new(T::shape()))
    }
    fn to_nickel(&self) -> NickelValue {
        match &self.0 {
            Some(value) => value.to_nickel(),
            None => NickelValue::null(),
        }
    }
    fn synthetic() -> Self {
        Nullable(Some(T::synthetic()))
    }
}

pub fn enum_tag(tag: &str) -> NickelValue {
    NickelValue::enum_tag_posless(LocIdent::from(Ident::new(tag)))
}

pub fn record(fields: impl IntoIterator<Item = (&'static str, NickelValue)>) -> NickelValue {
    container(NickelValue::record_posless(RecordData::with_field_values(
        fields.into_iter().map(|(name, value)| (LocIdent::from(Ident::new(name)), value)),
    )))
}

/// Nickel evaluates a record or an array whose elements are thunks or constants. A host-built
/// one holds plain values, so it is marked for the evaluator to closurize when it first meets
/// it. Without this a contract applied to a record that holds a record trips an assertion in
/// debug builds of Nickel.
fn container(value: NickelValue) -> NickelValue {
    NickelValue::term_posless(Term::Closurize(value))
}

/// Defines a host enum. On the wire it is one of the listed strings; in Nickel it is the enum
/// tag of the same name. The first variant is the synthetic value.
#[macro_export]
macro_rules! host_enum {
    ($(#[$meta:meta])* $vis:vis enum $name:ident { $($variant:ident => $tag:literal),+ $(,)? }) => {
        $(#[$meta])*
        #[derive(Debug, Clone, Copy, PartialEq, serde::Deserialize)]
        $vis enum $name { $(#[serde(rename = $tag)] $variant),+ }

        impl $crate::host::HostValue for $name {
            fn shape() -> $crate::host::Shape {
                $crate::host::Shape::Enum(&[$($tag),+])
            }
            fn to_nickel(&self) -> nickel_lang_core::eval::value::NickelValue {
                $crate::host::enum_tag(match self { $(Self::$variant => $tag),+ })
            }
            fn synthetic() -> Self {
                [$(Self::$variant),+][0]
            }
        }
    };
}

/// Defines a host record. Each field is written `"wireName" => rust_name: Type` under a one-line
/// doc comment, which is the field's description in `config schema`. Every field is required on
/// the wire.
#[macro_export]
macro_rules! host_record {
    (
        $(#[$meta:meta])* $vis:vis struct $name:ident {
            $(#[doc = $doc:literal] $wire:literal => $field:ident: $ty:ty),+ $(,)?
        }
    ) => {
        $(#[$meta])*
        #[derive(Debug, Clone, serde::Deserialize)]
        $vis struct $name { $(#[doc = $doc] #[serde(rename = $wire)] pub $field: $ty),+ }

        impl $crate::host::HostValue for $name {
            fn shape() -> $crate::host::Shape {
                $crate::host::Shape::Record {
                    name: stringify!($name),
                    fields: vec![$($crate::host::Field {
                        name: $wire,
                        shape: <$ty as $crate::host::HostValue>::shape(),
                        description: $doc.trim_ascii(),
                    }),+],
                }
            }
            fn to_nickel(&self) -> nickel_lang_core::eval::value::NickelValue {
                $crate::host::record([$(($wire, $crate::host::HostValue::to_nickel(&self.$field))),+])
            }
            fn synthetic() -> Self {
                Self { $($field: <$ty as $crate::host::HostValue>::synthetic()),+ }
            }
        }
    };
}
