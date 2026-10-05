import importlib.util
import pathlib
import unittest

path = pathlib.Path(__file__).resolve().parents[1] / '.claude/skills/demo/check-lens-film.py'
spec = importlib.util.spec_from_file_location('lens_film', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LensFilmTest(unittest.TestCase):
    def testMovieOriginAndVariableFrameTimesControlComparison(self):
        rows = module.compare([0, .01, .025, .045, .060, .080, .10, .12], 100,
                              [{'bootSeconds': 100.025}], [{'id': 1, 'totalMs': 50}], [5])
        self.assertAlmostEqual(rows[0]['visibleMs'], 55)
        self.assertAlmostEqual(rows[0]['differenceMs'], 5)
        self.assertEqual(rows[0]['differenceFrames'], 0)
        self.assertAlmostEqual(rows[0]['keySeconds'], .025)

    def testMissingOpeningsCannotSilentlyPass(self):
        with self.assertRaises(ValueError):
            module.compare([0, .1], 10, [{'bootSeconds': 10}], [], [1])

    def testCorruptedEncoderTimestampsCannotPassTheClockCheck(self):
        metadata = {'firstPTS': 100, 'framePTS': [100, 100.01, 100.025]}
        module.validate_sample_times([0, .01, .025], metadata)
        with self.assertRaises(ValueError):
            module.validate_sample_times([0, .01, -.975], metadata)
        with self.assertRaises(ValueError):
            module.validate_sample_times([0, .01, .050], metadata)
        with self.assertRaises(ValueError):
            module.validate_sample_times([0], metadata)

    def testDroppedFirstSampleCannotShiftTheRecordingOrigin(self):
        with self.assertRaises(ValueError):
            module.validate_sample_times([.01, .025], {'firstPTS': 100, 'framePTS': [100.01, 100.025]})

    def testStripEdgeRejectsBackgroundMotionAndAcceptsTheSurface(self):
        self.assertFalse(module.strip_edge_present([100] * 10, [100] * 10, [100] * 10))
        self.assertFalse(module.strip_edge_present([240] * 10, [240] * 10, [40] * 10))
        self.assertFalse(module.strip_edge_present([240] * 2 + [40] * 8, [40] * 10, [40] * 10))
        self.assertTrue(module.strip_edge_present([200] * 10, [40] * 10, [100] * 10))
