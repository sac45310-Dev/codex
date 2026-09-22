#!/usr/bin/env python3
"""Tests for email_extract. Run: python3 test_email_extract.py"""
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import email_extract as ex  # noqa: E402


def cfencode(addr, key=0x7a):
    """Build a data-cfemail blob the way Cloudflare does, for round-trip tests."""
    return "%02x" % key + "".join("%02x" % (ord(c) ^ key) for c in addr)


class TestDecode(unittest.TestCase):
    def test_roundtrip(self):
        for addr in ["jane.doe@focus.org", "a@b.co", "x.y+z@sub.example.org"]:
            self.assertEqual(ex.decode_cfemail(cfencode(addr)), addr)

    def test_bad_blob(self):
        self.assertIsNone(ex.decode_cfemail("zzzz"))
        self.assertIsNone(ex.decode_cfemail("7a"))
        self.assertIsNone(ex.decode_cfemail(""))

    def test_blob_without_at_rejected(self):
        self.assertIsNone(ex.decode_cfemail(cfencode("not-an-address")))


class TestJunk(unittest.TestCase):
    def test_placeholder_rejected(self):
        # The literal Cloudflare renders. Storing it would look like success.
        self.assertTrue(ex.is_junk("[email protected]"))
        self.assertTrue(ex.is_junk("[email&#160;protected]"))

    def test_asset_filenames_rejected(self):
        self.assertTrue(ex.is_junk("sprite@2x.png"))
        self.assertTrue(ex.is_junk("font@1x.woff2"))

    def test_real_address_kept(self):
        self.assertFalse(ex.is_junk("jane.doe@focus.org"))


class TestExtract(unittest.TestCase):
    def test_mailto(self):
        h = '<a href="mailto:jane.doe@focus.org">Email Jane</a>'
        self.assertEqual(ex.extract_emails(h), ["jane.doe@focus.org"])

    def test_cfemail_decoded_not_placeholder(self):
        h = ('<a href="/cdn-cgi/l/email-protection" '
             'data-cfemail="%s">[email&#160;protected]</a>' % cfencode("bob@focus.org"))
        got = ex.extract_emails(h)
        self.assertIn("bob@focus.org", got)
        self.assertFalse(any("protected" in g for g in got))

    def test_script_noise_ignored(self):
        h = ('<script>var t="tracker@analytics.js";</script>'
             '<p>Contact sue@focus.org</p>')
        self.assertEqual(ex.extract_emails(h), ["sue@focus.org"])

    def test_dedupes_case_insensitively(self):
        h = '<p>A@focus.org and a@focus.org</p>'
        self.assertEqual(len(ex.extract_emails(h)), 1)

    def test_no_email(self):
        self.assertEqual(ex.extract_emails("<p>Support this missionary</p>"), [])


class TestClassify(unittest.TestCase):
    def test_role_mailbox(self):
        self.assertEqual(ex.classify("giving@focus.org", "Jane Doe", 1, 3), "role")
        self.assertEqual(ex.classify("info@focus.org", "Jane Doe", 1, 3), "role")

    def test_personal(self):
        self.assertEqual(ex.classify("jane.doe@focus.org", "Jane Doe", 1, 3), "direct")

    def test_shared_address_demoted(self):
        # Same address on 900 pages is the switchboard, not a person.
        self.assertEqual(ex.classify("team@focus.org", "Jane Doe", 900, 3), "role")
        self.assertEqual(ex.classify("jane.doe@focus.org", "Jane Doe", 900, 3), "org")

    def test_name_overlap(self):
        self.assertTrue(ex.name_overlap("jane.doe@focus.org", "Jane Doe"))
        self.assertFalse(ex.name_overlap("xk9@focus.org", "Jane Doe"))


class TestEmitEndToEnd(unittest.TestCase):
    def test_emit_marks_shared_address_as_org(self):
        d = tempfile.mkdtemp()
        html_dir = os.path.join(d, "html")
        os.makedirs(html_dir)
        ids = ["11111111-1111-1111-1111-11111111111%d" % i for i in range(5)]
        wl = os.path.join(d, "w.csv")
        with open(wl, "w", encoding="utf-8") as fh:
            fh.write("scout_candidate_id,lead_id,agency_key,person_name,url\n")
            for i, sid in enumerate(ids):
                fh.write("%s,22222222-2222-2222-2222-22222222222%d,focus,"
                         "Person %d,https://focus.org/missionaries/p%d\n"
                         % (sid, i, i, i))
        # Four pages share one address; the fifth has its own.
        for i, sid in enumerate(ids):
            addr = "shared@focus.org" if i < 4 else "solo.person@focus.org"
            with open(os.path.join(html_dir, "%s.html" % sid), "w",
                      encoding="utf-8") as fh:
                fh.write('<a href="mailto:%s">mail</a>' % addr)
        out = os.path.join(d, "o.sql")
        rc = subprocess.run(
            [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          "email_extract.py"),
             "emit", "--worklist", wl, "--html-dir", html_dir,
             "--out", out, "--tag", "t1", "--shared-max", "3"],
            capture_output=True, text=True)
        self.assertEqual(rc.returncode, 0, rc.stderr)
        self.assertIn("org=4", rc.stdout)
        self.assertIn("direct=1", rc.stdout)
        sql = open(out, encoding="utf-8").read()
        self.assertIn("solo.person@focus.org", sql)
        self.assertIn("email_provenance", sql)
        # Nothing inferred is ever emitted: every row is provenance 'published'
        # and no emitted SQL value carries an inferred marker.
        self.assertIn("'email_provenance', 'published'", sql)
        self.assertNotIn("'inferred'", sql)

    def test_missing_html_counted_not_fatal(self):
        d = tempfile.mkdtemp()
        html_dir = os.path.join(d, "html")
        os.makedirs(html_dir)
        wl = os.path.join(d, "w.csv")
        with open(wl, "w", encoding="utf-8") as fh:
            fh.write("scout_candidate_id,lead_id,agency_key,person_name,url\n")
            fh.write("33333333-3333-3333-3333-333333333333,"
                     "44444444-4444-4444-4444-444444444444,focus,No Page,"
                     "https://focus.org/missionaries/none\n")
        out = os.path.join(d, "o.sql")
        rc = subprocess.run(
            [sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          "email_extract.py"),
             "emit", "--worklist", wl, "--html-dir", html_dir,
             "--out", out, "--tag", "t2"],
            capture_output=True, text=True)
        self.assertEqual(rc.returncode, 0, rc.stderr)
        self.assertIn("missing_html=1", rc.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
