"""Insere/reordena uma fase da campanha, renumerando os arquivos automaticamente.

Abre um seletor de arquivo para escolher uma fase (.json), pergunta qual
numero de fase ela deve ocupar e renomeia os arquivos em levels/campaign/
para que a numeracao fique sequencial (level_01.json, level_02.json, ...),
sem lacunas.

- Se o arquivo escolhido ja estiver em levels/campaign, ele e movido para a
  nova posicao (as demais fases se deslocam para abrir espaco).
- Se o arquivo escolhido estiver fora de levels/campaign, uma copia dele e
  inserida na posicao escolhida (o arquivo original nao e alterado).
- A nova fase e inserida imediatamente antes da primeira fase existente cujo
  numero atual (no nome do arquivo) seja >= ao numero informado. Depois
  disso, TODAS as fases sao renumeradas em sequencia (1, 2, 3, ...), o que
  elimina lacunas automaticamente. Por exemplo, com as fases 1, 3, 4, 5
  (falta a 2) e pedindo a posicao 4: a nova entra antes da antiga "4",
  e a renumeracao final e 1, 2 (antiga 3), 3 (nova), 4 (antiga 4),
  5 (antiga 5) — a antiga 4 e a antiga 5 acabam preservando os numeros
  4 e 5 porque o buraco em 2 foi preenchido pela antiga 3.
- O campo "name" dentro do JSON (ex.: "Fase 3") e atualizado junto, mas so
  quando ja segue esse padrao — nomes customizados sao preservados.
- Se nenhum arquivo for selecionado no seletor (dialogo cancelado), o script
  apenas remove lacunas existentes na numeracao da campanha, sem inserir
  nada de novo.

Uso: python tools/renumber_campaign_level.py
"""

import bisect
import json
import re
import shutil
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog

SCRIPT_DIR = Path(__file__).resolve().parent
CAMPAIGN_DIR = SCRIPT_DIR.parent / "levels" / "campaign"

LEVEL_FILE_PATTERN = re.compile(r"^level_(\d+)\.json$", re.IGNORECASE)
NAME_LINE_PATTERN = re.compile(r'^(\t"name":\s*)"([^"]*)"(,?)\s*$', re.MULTILINE)
FASE_NAME_PATTERN = re.compile(r"^Fase \d+$")


def list_campaign_levels() -> list[Path]:
    """Fases existentes, ordenadas pelo numero no nome do arquivo (lacunas incluídas)."""
    entries = []
    for path in CAMPAIGN_DIR.glob("*.json"):
        match = LEVEL_FILE_PATTERN.match(path.name)
        number = int(match.group(1)) if match else None
        entries.append((number is None, number, path.name, path))
    entries.sort()
    return [path for *_, path in entries]


def is_pacmaze_level(path: Path) -> bool:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return isinstance(data, dict) and data.get("format") == "pacmaze-level"


def update_internal_name(path: Path, position: int) -> None:
    text = path.read_text(encoding="utf-8")
    match = NAME_LINE_PATTERN.search(text)
    if not match:
        return
    current_name = match.group(2)
    if current_name and not FASE_NAME_PATTERN.match(current_name):
        return
    new_line = f'{match.group(1)}"Fase {position}"{match.group(3)}'
    new_text = text[: match.start()] + new_line + text[match.end() :]
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")


def split_matched(paths: list[Path]) -> tuple[list[tuple[int, Path]], list[Path]]:
    """Separa arquivos que seguem level_NN.json (com seu numero) dos demais."""
    matched: list[tuple[int, Path]] = []
    unmatched: list[Path] = []
    for path in paths:
        match = LEVEL_FILE_PATTERN.match(path.name)
        if match:
            matched.append((int(match.group(1)), path))
        else:
            unmatched.append(path)
    matched.sort(key=lambda item: item[0])
    return matched, unmatched


def apply_new_order(new_order: list[Path], new_path: Path | None) -> list[tuple[str, str]]:
    """Renomeia os arquivos de new_order para level_01.json, level_02.json, ...

    new_path (se houver) e um arquivo que ainda nao esta no nome final: sera
    copiado (se vier de fora de CAMPAIGN_DIR) ou movido (se ja estiver la).
    Os demais arquivos de new_order ja existem em CAMPAIGN_DIR e sao apenas
    renomeados. Retorna a lista de mudancas (nome antigo -> nome novo).
    """
    total = len(new_order)
    digits = max(2, len(str(total)))

    def final_name(index: int) -> str:
        return f"level_{index + 1:0{digits}d}.json"

    # Fase 1: libera os nomes finais renomeando os arquivos já existentes na
    # campanha para nomes temporários, evitando colisões durante a troca.
    temp_map: dict[Path, Path] = {}
    for path in new_order:
        if path == new_path:
            continue
        temp_path = path.with_name(path.name + ".tmp_reorder")
        path.rename(temp_path)
        temp_map[path] = temp_path

    # Fase 2: coloca cada arquivo no nome final e atualiza o campo "name".
    changes = []
    for index, path in enumerate(new_order):
        target = CAMPAIGN_DIR / final_name(index)
        if path == new_path:
            if new_path.parent.resolve() == CAMPAIGN_DIR.resolve():
                if new_path != target:
                    new_path.rename(target)
            else:
                shutil.copy2(new_path, target)
            changes.append((new_path.name + "  (novo)", target.name))
        else:
            source = temp_map[path]
            source.rename(target)
            changes.append((path.name, target.name))
        update_internal_name(target, index + 1)

    return [(old, new) for old, new in changes if old != new]


def insert_level(chosen_path: Path) -> None:
    """Insere/move chosen_path para a posição escolhida pelo usuário e elimina lacunas."""
    existing = [p for p in list_campaign_levels() if p.resolve() != chosen_path]
    matched, unmatched = split_matched(existing)
    numbers = [number for number, _ in matched]

    default_position = (numbers[-1] + 1) if numbers else 1
    position = simpledialog.askinteger(
        "Posição da fase",
        f"Existem {len(existing)} fase(s) na campanha.\n"
        f"Qual número de fase este arquivo deve ocupar (1 a {default_position})?\n\n"
        "Se esse número estiver ocupado, a fase nova entra no lugar dela e as "
        "demais se deslocam; lacunas na numeração são preenchidos automaticamente.",
        initialvalue=default_position,
        minvalue=1,
        maxvalue=default_position,
    )
    if position is None:
        return

    insert_index = bisect.bisect_left(numbers, position)
    new_order = [path for _, path in matched]
    new_order.insert(insert_index, chosen_path)
    new_order.extend(unmatched)  # arquivos fora do padrão level_NN.json vão ao final

    changes = apply_new_order(new_order, chosen_path)
    summary = "\n".join(f"{old} -> {new}" for old, new in changes)
    messagebox.showinfo(
        "Campanha atualizada",
        f"Fase inserida na posição {position} (total: {len(new_order)} fases).\n\n{summary}",
    )


def compact_levels() -> None:
    """Remove lacunas na numeração das fases existentes, sem inserir nada novo."""
    matched, unmatched = split_matched(list_campaign_levels())
    new_order = [path for _, path in matched] + unmatched
    if not new_order:
        messagebox.showinfo("Campanha", "Nenhuma fase encontrada em levels/campaign.")
        return

    changes = apply_new_order(new_order, None)
    if not changes:
        messagebox.showinfo("Campanha", "A numeração já está sem lacunas, nada para ajustar.")
        return

    summary = "\n".join(f"{old} -> {new}" for old, new in changes)
    messagebox.showinfo("Campanha atualizada", f"Lacunas removidas.\n\n{summary}")


def main() -> None:
    root = tk.Tk()
    root.withdraw()

    initial_dir = CAMPAIGN_DIR if CAMPAIGN_DIR.exists() else SCRIPT_DIR.parent
    chosen = filedialog.askopenfilename(
        title="Selecione o arquivo da fase (.json) — cancele para só remover lacunas",
        initialdir=str(initial_dir),
        filetypes=[("Fases do Pacmaze", "*.json"), ("Todos os arquivos", "*.*")],
    )

    CAMPAIGN_DIR.mkdir(parents=True, exist_ok=True)

    if not chosen:
        compact_levels()
        return

    chosen_path = Path(chosen).resolve()
    if not is_pacmaze_level(chosen_path):
        messagebox.showerror(
            "Fase inválida",
            f"O arquivo escolhido não parece ser uma fase válida do Pacmaze:\n{chosen_path}",
        )
        return

    insert_level(chosen_path)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - mostra qualquer erro ao usuário
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror("Erro", f"Falha ao reordenar a campanha:\n{exc}")
        raise
