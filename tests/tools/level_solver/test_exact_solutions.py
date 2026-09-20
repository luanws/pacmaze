import unittest
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).parent.parent.parent.parent.resolve()
TOOLS_DIR = PROJECT_ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from level_solver import Fase, CAMPAIGN_DIR

EXPECTED_SOLUTIONS = {
    "level_01.json": ">^>v<v>v<^<^<v>",
    "level_02.json": ">^<^>^<v>v<v>^<v>^",
    "level_03.json": ">^>^<^>^>v<",
    "level_04.json": "^>^>v<v>^>v<^",
    "level_05.json": "^>^>v>^>v<v>^<^<^>^>^<^>^<v<^>^>v>^>^>v>v<v>v>v>^>^>v>v>^>^",
    "level_06.json": ">^<v>v>^<^<^<^<^>^<^>^>^>v>^>v>^>v>v>v>v<v<v<v<^<^<v<^>v<v<^<v<^<v<^>v>v>^>v>^<v<v>v",
    "level_07.json": "^>^<v>^<v>v<^>v<^>v<^<v>v>^>v<v<",
    "level_08.json": ">^<^>^<^>^<v<v<^>v>^>^>v>^>v<^<^>v>^<v<v>^<^>^<^>^>^<^<",
    "level_09.json": ">v>^>v<^>>>v<^>^<^>^>^",
    "level_10.json": "^>v<v>v>^<^>^>^^^>v<^<^>v<",
    "level_11.json": "^<v>^>v<>^<>^>>v>v<^<^<v>^>v>>^",
    "level_12.json": "^>v<^<v<^>^<v>v>^>^^>v<v>^^^<^<^>v>^>v",
    "level_13.json": "<v<v>v<^>^<^>v>>v>v>^^^>v>^>>v>^>v<^^^<",
    "level_14.json": ">^<^<v>^>vvv<v>v>^>v<>v<^<v><^<<<^>^^^>^<^>v<v",
    "level_15.json": "v<^>v<>^<^>^>>>v<v>^<v>v>^<v^<v>v>v>v>>>v<v<^<^>>>v>",
    "level_16.json": "<v<^>v>^>^<^<>^<>v<^<v<<>v<v<^>v>^<^>^>^<v>v<^<^>>>v>^<v",
    "level_17.json": "<^>v>v<^<^^>v>^>v<v>v<^>^>v<^<v>vv>^<v<v<^<^>v<^>v>>>vv>^<^<^>",
    "level_18.json": ">^<v<v>v<^>^<v>^>^<v<v>v>v^<v>^>^>v>>>^<>v>v<^^^<<>^<v<^<^<vvv>^<^>",
    "level_19.json": "^>^<^<^>^<v>v>^>>>^<v>v<v>^>^<^>v>>^<v<^>v<v<v>^<>v<^>^>>v>^<^<v>>>v>",
    "level_20.json": "v<^<v>^<v>v>^>>^<^>v<v<^>v>vv<^>v<v>^<^>v^<^>v<v>^<<<v<^>^<v<v<v<^>v>^<^^>^<v>",
    "level_21.json": "^>v>>^>^>",
    "level_22.json": "^>^^^^^v<^>^",
    "level_23.json": "^>^<^^^^^v>^<^v>v>>^>^<",
    "level_24.json": ">^<^^^^^>^<^>v>^<<<<v<^>",
    "level_25.json": ">vv<v>v^>^^^<v<^<v>^^^<^>^^<v<^<v>^^<^>^<v>"
}

class TestExactSolutions(unittest.TestCase):
    """Garante que todas as fases resultam na solução exata encontrada na tabela."""

    def test_all_expected_solutions(self):
        """Verifica se cada fase tem a solução exata correspondente à mapeada."""
        for filename, expected_solution in EXPECTED_SOLUTIONS.items():
            path = CAMPAIGN_DIR / filename
            with self.subTest(level=filename):
                self.assertTrue(path.exists(), f"Arquivo {filename} não encontrado.")
                
                level = Fase.carregar(path)
                solution = level.resolver()
                
                self.assertIsNotNone(solution, f"A fase {filename} falhou ao tentar resolver.")
                self.assertEqual(solution, expected_solution, f"A solução gerada para {filename} mudou!")

if __name__ == "__main__":
    unittest.main()
