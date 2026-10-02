//! What is derived from the records: the Nickel contracts and the output of `config schema`.

use serde_json::{Value, json};

use crate::{
    host::{Field, HostValue, Shape},
    records::{CONTRACT_VERSION, Column, FilterContext, Window},
};

/// Every record of the contract with its fields, each record once, a record before the records
/// its fields hold.
pub fn records() -> Vec<(&'static str, Vec<Field>)> {
    let mut records = Vec::new();
    for shape in [Window::shape(), FilterContext::shape(), Column::shape()] {
        collect(&shape, &mut records);
    }
    records
}

fn collect(shape: &Shape, records: &mut Vec<(&'static str, Vec<Field>)>) {
    match shape {
        Shape::Record { name, fields } => {
            if records.iter().any(|(known, _)| known == name) {
                return;
            }
            records.push((name, fields.clone()));
            for field in fields {
                collect(&field.shape, records);
            }
        }
        Shape::Array(inner) | Shape::Nullable(inner) => collect(inner, records),
        Shape::String | Shape::Bool | Shape::Number | Shape::Enum(_) => {}
    }
}

/// The shipped `winmux/contract.ncl`: one Nickel contract per record.
pub fn nickel_contracts() -> String {
    let mut out = String::from(
        "# Generated from nickel-helper/src/records.rs. Do not edit: run `make contract`.\n\
         #\n\
         # The records WinMux hands to Filters and Policy hooks. `winmux config schema` describes\n\
         # every field.\n\
         let Nullable = fun Contract =>\n  \
           std.contract.custom (fun label value =>\n    \
             if value == null then 'Ok value else std.contract.check Contract label value\n  \
           )\n\
         in\n\
         {\n",
    );
    out.push_str(&format!("  contract-version = {CONTRACT_VERSION},\n"));
    for (name, fields) in records() {
        out.push_str(&format!("\n  {name} = {{\n"));
        for field in fields {
            out.push_str(&format!("    {} | {},\n", field.name, nickel_contract(&field.shape)));
        }
        out.push_str("  },\n");
    }
    out.push_str("}\n");
    out
}

fn nickel_contract(shape: &Shape) -> String {
    match shape {
        Shape::String => "String".to_owned(),
        Shape::Bool => "Bool".to_owned(),
        Shape::Number => "Number".to_owned(),
        Shape::Enum(tags) => format!("[| {} |]", tags.iter().map(|tag| format!("'{tag}")).collect::<Vec<_>>().join(", ")),
        Shape::Array(inner) => format!("Array {}", nickel_atom(inner)),
        Shape::Nullable(inner) => format!("Nullable {}", nickel_atom(inner)),
        Shape::Record { name, .. } => (*name).to_owned(),
    }
}

fn nickel_atom(shape: &Shape) -> String {
    match shape {
        Shape::Array(_) | Shape::Nullable(_) => format!("({})", nickel_contract(shape)),
        _ => nickel_contract(shape),
    }
}

fn type_name(shape: &Shape) -> String {
    match shape {
        Shape::String => "String".to_owned(),
        Shape::Bool => "Bool".to_owned(),
        Shape::Number => "Number".to_owned(),
        Shape::Enum(_) => "Enum".to_owned(),
        Shape::Array(inner) => format!("Array of {}", type_name(inner)),
        Shape::Nullable(inner) => format!("{} or null", type_name(inner)),
        Shape::Record { name, .. } => (*name).to_owned(),
    }
}

fn enum_tags(shape: &Shape) -> &'static [&'static str] {
    match shape {
        Shape::Enum(tags) => tags,
        Shape::Array(inner) | Shape::Nullable(inner) => enum_tags(inner),
        _ => &[],
    }
}

/// `config schema --json`.
pub fn schema_json() -> Value {
    let records: serde_json::Map<String, Value> = records()
        .into_iter()
        .map(|(name, fields)| {
            let fields: Vec<Value> = fields
                .iter()
                .map(|field| {
                    json!({
                        "name": field.name,
                        "type": type_name(&field.shape),
                        "enum": enum_tags(&field.shape),
                        "description": field.description,
                    })
                })
                .collect();
            (name.to_owned(), Value::Array(fields))
        })
        .collect();
    json!({ "contract-version": CONTRACT_VERSION, "records": records })
}

/// `config schema`.
pub fn schema_text() -> String {
    let records = records();
    let all = || records.iter().flat_map(|(_, fields)| fields);
    let name_width = all().map(|field| field.name.len()).max().unwrap_or(0);
    let type_width = all().map(|field| type_name(&field.shape).len()).max().unwrap_or(0);
    let mut out = format!("contract-version {CONTRACT_VERSION}\n");
    for (name, fields) in &records {
        out.push_str(&format!("\n{name}\n"));
        for field in fields {
            let ty = type_name(&field.shape);
            out.push_str(&format!("  {:name_width$}  {ty:type_width$}  {}\n", field.name, field.description));
            let tags = enum_tags(&field.shape);
            if !tags.is_empty() {
                let tags: Vec<String> = tags.iter().map(|tag| format!("'{tag}")).collect();
                out.push_str(&format!("  {:name_width$}  {:type_width$}  {}\n", "", "", tags.join(", ")));
            }
        }
    }
    out
}
