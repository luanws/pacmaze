import unittest
from pathlib import Path
import sys

# Garante que o diretório tools está no path para podermos importar o level_solver
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent.resolve()
TOOLS_DIR = PROJECT_ROOT / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from level_solver import Fase, CAMPAIGN_DIR

class TestCampaignLevels(unittest.TestCase):
    """Conjunto de testes automatizados para as fases da campanha."""

    def test_specific_levels_are_solvable(self):
        """Garante que as fases 18, 19 e 20 são resolvíveis e não possuem falhas."""
        target_levels = ["level_18.json", "level_19.json", "level_20.json"]
        
        for filename in target_levels:
            path = CAMPAIGN_DIR / filename
            with self.subTest(level=filename):
                self.assertTrue(path.exists(), f"Arquivo {filename} não encontrado.")
                
                level = Fase.carregar(path)
                
                problems = level.problemas()
                self.assertFalse(problems, f"A fase {filename} relatou problemas de validação: {problems}")
                
                solution = level.resolver()
                self.assertIsNotNone(solution, f"A fase {filename} não é resolvível (sem solução).")

    def test_all_campaign_levels_are_solvable(self):
        """Garante que todas as fases da campanha são resolvíveis."""
        paths = sorted(CAMPAIGN_DIR.glob("*.json"))
        self.assertTrue(len(paths) > 0, "Nenhuma fase encontrada no diretório da campanha.")
        
        for path in paths:
            with self.subTest(level=path.name):
                level = Fase.carregar(path)
                
                problems = level.problemas()
                self.assertFalse(problems, f"A fase {path.name} relatou problemas de validação: {problems}")
                
                solution = level.resolver()
                self.assertIsNotNone(solution, f"A fase {path.name} não é resolvível (sem solução).")

if __name__ == "__main__":
    unittest.main()
