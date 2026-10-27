import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import routes
from config import MAX_TEXT


class Registry(unittest.TestCase):
    def test_terminal_route_is_indexed(self):
        rows = [row for row in routes.parse_registry()["rows"] if any(entry["path"] == "modules/terminal.nix" for entry in row["paths"])]
        self.assertTrue(rows)

    def test_every_route_has_a_path_and_hosts(self):
        for row in routes.parse_registry()["rows"]:
            self.assertTrue(row["paths"], row["task"])
            self.assertTrue(row["hosts"], row["task"])

    def test_swap_route_is_scoped_to_server(self):
        rows = [
            row
            for row in routes.parse_registry()["rows"]
            if any(entry["path"] == "modules/swap.nix" for entry in row["paths"])
        ]
        self.assertIn("server", rows[0]["hosts"])

    def test_note_anchors_resolve(self):
        known = routes.doc_targets()
        for row in routes.parse_registry()["rows"]:
            if row["doc"].startswith("docs/routes-notes.md#"):
                self.assertIn(row["doc"], known, row["task"])


class Tokenizing(unittest.TestCase):
    def test_cyrillic_query_maps_to_english_term(self):
        self.assertIn("terminal", routes.tokenize("настроить терминал"))

    def test_cyrillic_swap_maps(self):
        self.assertIn("swap", routes.tokenize("свап"))


class RoutingQueries(unittest.TestCase):
    def best(self, query, host=None):
        text, _ = routes.tool_route({"query": query, "host": host, "limit": 1}, "test", "test")
        return json.loads(text)

    def test_russian_terminal_query_is_confident(self):
        data = self.best("настроить терминал")
        self.assertTrue(data["confident"])
        self.assertEqual(data["matches"][0]["paths"][0]["path"], "modules/terminal.nix")

    def test_swap_on_server_prefers_swap_module(self):
        data = self.best("swap", "server")
        self.assertEqual(data["matches"][0]["paths"][0]["path"], "modules/swap.nix")

    def test_unknown_query_is_not_confident(self):
        data = self.best("zzzz")
        self.assertFalse(data["confident"])
        self.assertEqual(data["matches"], [])

    def test_reverse_lookup_finds_terminal(self):
        text, _ = routes.tool_route_file({"path": "modules/terminal.nix"}, "test", "test")
        data = json.loads(text)
        self.assertTrue(data["routed"])

    def test_route_and_audit_payloads_stay_valid_json(self):
        text, _ = routes.tool_route({"query": "model", "limit": 25}, "test", "test")
        self.assertLessEqual(len(text), MAX_TEXT)
        json.loads(text)
        text, _ = routes.tool_routes_audit({"group": "System Modules"}, "test", "test")
        self.assertLessEqual(len(text), MAX_TEXT)
        data = json.loads(text)
        self.assertFalse(data["index_stale"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
