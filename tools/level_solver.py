"""Resolve e audita fases do Pacmaze sem abrir o jogo.

Simula as mesmas regras de scripts/player.gd e scripts/level.gd: o pac desliza
até bater, empurrar um caixote faz ele andar exatamente uma casa, a pílula é
pega de passagem, os portais trocam de lugar e uma porta só abre com a chave da
cor dela. Com isso responde três perguntas que o playtest manual demora a
responder:

- a fase tem solução? em quantos comandos?
- os caixotes são mesmo necessários, ou dá para vencer sem tocar neles?
- existem becos sem volta, isto é, casas de onde o jogador nunca mais alcança a
  pílula e precisa reiniciar a fase?

Uso:

    python tools/level_solver.py                          # toda a campanha
    python tools/level_solver.py levels/campaign/level_21.json ...
    python tools/level_solver.py --mapa   level_21.json   # desenha o mapa
    python tools/level_solver.py --becos  level_21.json   # marca os becos com X

Os fantasmas são ignorados na busca: eles andam em circuito fixo e o pac pode
esperar o momento de passar, então não mudam o que é alcançável. O script só
confere se cada ronda fecha o circuito e cabe no mapa.
"""

import argparse
import json
import sys
from collections import deque
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CAMPAIGN_DIR = SCRIPT_DIR.parent / "levels" / "campaign"

## Cada tecla e o passo que ela dá, no mesmo sentido de Player.DIRECTIONS.
DIRECOES = {"^": (0, -1), "v": (0, 1), "<": (-1, 0), ">": (1, 0)}
## Um deslize nunca cruza o mapa mais vezes que isto: corta ciclos de portal.
LIMITE_DESLIZE = 4000


class Fase:
    """Uma fase carregada do JSON, no formato descrito em scripts/level_data.gd."""

    def __init__(self, dados, nome_arquivo=""):
        self.nome = dados.get("name", nome_arquivo)
        self.largura, self.altura = dados.get("size", [43, 27])
        self.paredes = {tuple(p["cell"]) for p in dados.get("walls", [])}
        self.caixotes = {tuple(p["cell"]) for p in dados.get("pushable_walls", [])}
        self.pac = tuple(dados["player"])
        self.pilula = tuple(dados["pill"])
        self.fantasmas = dados.get("ghosts", [])
        self.portas = [tuple(l["door"]) for l in dados.get("locks", [])]
        self.chaves = [tuple(l["key"]) for l in dados.get("locks", [])]
        # Cada portal leva ao par dele; os dois trocam de lugar, então as duas
        # casas continuam sendo as mesmas e o destino não depende do histórico.
        self.portais = {}
        for p in dados.get("portals", []):
            a, b = tuple(p["a"]), tuple(p["b"])
            self.portais[a] = b
            self.portais[b] = a

    @classmethod
    def carregar(cls, caminho):
        caminho = Path(caminho)
        dados = json.loads(caminho.read_text(encoding="utf-8"))
        if dados.get("format") != "pacmaze-level":
            raise ValueError("%s não é uma fase do Pacmaze" % caminho.name)
        return cls(dados, caminho.stem)

    def dentro(self, casa):
        x, y = casa
        return 0 < x < self.largura - 1 and 0 < y < self.altura - 1

    def _fechada(self, casa, caixotes, abertas):
        if not self.dentro(casa) or casa in self.paredes or casa in caixotes:
            return True
        return any(casa == porta and not (abertas >> i) & 1
                   for i, porta in enumerate(self.portas))

    def _pegar_chaves(self, casa, mao):
        for i, chave in enumerate(self.chaves):
            if casa == chave:
                mao |= 1 << i
        return mao

    def _deslizar(self, pac, passo, caixotes, mao, abertas):
        """Escorrega até bater. Devolve (casa final, chaves na mão, pegou a pílula)."""
        dx, dy = passo
        atual = pac
        for _ in range(LIMITE_DESLIZE):
            frente = (atual[0] + dx, atual[1] + dy)
            if self._fechada(frente, caixotes, abertas):
                break
            atual = frente
            if atual == self.pilula:
                return atual, mao, True
            mao = self._pegar_chaves(atual, mao)
            destino = self.portais.get(atual)
            if destino is not None:
                atual = destino
                if atual == self.pilula:
                    return atual, mao, True
                mao = self._pegar_chaves(atual, mao)
        return atual, mao, False

    def vizinhos(self, estado):
        """Os estados a um comando de distância. Marca com venceu=True quem pega a pílula."""
        pac, caixotes, mao, abertas = estado
        conjunto = set(caixotes)
        for tecla, (dx, dy) in DIRECOES.items():
            frente = (pac[0] + dx, pac[1] + dy)
            # 1) Encostar numa porta com a chave dela: abre e o pac fica parado.
            porta = next((i for i, d in enumerate(self.portas)
                          if d == frente and not (abertas >> i) & 1 and (mao >> i) & 1), None)
            if porta is not None:
                yield tecla, (pac, caixotes, mao, abertas | (1 << porta)), False
                continue
            # 2) Empurrar um caixote: ele anda uma casa e o pac ocupa o lugar dele.
            if frente in conjunto:
                atras = (frente[0] + dx, frente[1] + dy)
                if not self._fechada(atras, conjunto, abertas):
                    novos = set(conjunto)
                    novos.discard(frente)
                    novos.add(atras)
                    yield (tecla,
                           (frente, tuple(sorted(novos)), self._pegar_chaves(frente, mao), abertas),
                           False)
                continue
            # 3) Deslizar até bater.
            parou, nova_mao, venceu = self._deslizar(pac, (dx, dy), conjunto, mao, abertas)
            if venceu:
                yield tecla, None, True
            elif parou != pac:
                yield tecla, (parou, caixotes, nova_mao, abertas), False

    def inicio(self):
        return (self.pac, tuple(sorted(self.caixotes)), 0, 0)

    def resolver(self):
        """Busca em largura: devolve a sequência de teclas mais curta, ou None."""
        vistos = {self.inicio()}
        fila = deque([(self.inicio(), "")])
        while fila:
            estado, caminho = fila.popleft()
            for tecla, seguinte, venceu in self.vizinhos(estado):
                if venceu:
                    return caminho + tecla
                if seguinte not in vistos:
                    vistos.add(seguinte)
                    fila.append((seguinte, caminho + tecla))
        return None

    def explorar(self):
        """Todos os estados alcançáveis e quais deles ainda conseguem vencer."""
        vistos = {self.inicio()}
        saidas, vitorias = {}, set()
        fila = deque([self.inicio()])
        while fila:
            estado = fila.popleft()
            saidas[estado] = []
            for _tecla, seguinte, venceu in self.vizinhos(estado):
                if venceu:
                    vitorias.add(estado)
                    continue
                saidas[estado].append(seguinte)
                if seguinte not in vistos:
                    vistos.add(seguinte)
                    fila.append(seguinte)
        # De trás para frente: quem chega a um estado vivo também está vivo.
        entradas = {}
        for estado, seguintes in saidas.items():
            for seguinte in seguintes:
                entradas.setdefault(seguinte, []).append(estado)
        vivos, fila = set(vitorias), deque(vitorias)
        while fila:
            estado = fila.popleft()
            for anterior in entradas.get(estado, []):
                if anterior not in vivos:
                    vivos.add(anterior)
                    fila.append(anterior)
        return vistos, vivos

    def _copia_com(self, caixotes, congelados):
        gemea = Fase.__new__(Fase)
        gemea.__dict__.update(self.__dict__)
        gemea.paredes = self.paredes | congelados
        gemea.caixotes = caixotes
        return gemea

    def caixotes_necessarios(self):
        """Para cada caixote, diz se dá para vencer sem tirá-lo do lugar."""
        resposta = {}
        for casa in sorted(self.caixotes, key=lambda c: (c[1], c[0])):
            gemea = self._copia_com(self.caixotes - {casa}, {casa})
            resposta[casa] = gemea.resolver()
        return resposta

    def problemas(self):
        """Erros de montagem que o jogo não perdoa, mais avisos sobre os fantasmas."""
        achados = []
        ocupadas = self.paredes | self.caixotes
        if self.pac in ocupadas:
            achados.append("o pac está sobre uma parede")
        if self.pilula in ocupadas:
            achados.append("a pílula está sobre uma parede")
        if self.pac == self.pilula:
            achados.append("o pac e a pílula estão na mesma casa")
        for casa in self.chaves + self.portas:
            if casa in ocupadas:
                achados.append("há uma chave ou porta sobre uma parede, em %s" % (casa,))
        for casa in self.portais:
            if casa in ocupadas:
                achados.append("há um portal sobre uma parede, em %s" % (casa,))
        for fantasma in self.fantasmas:
            casa = tuple(fantasma["cell"])
            rota = [tuple(p) for p in fantasma.get("path", [])]
            volta = (sum(p[0] for p in rota), sum(p[1] for p in rota))
            if rota and volta != (0, 0):
                achados.append("a ronda do fantasma %s em %s não fecha o circuito"
                               % (fantasma.get("color"), casa))
            pos = casa
            for passo in rota:
                pos = (pos[0] + passo[0], pos[1] + passo[1])
                if not self.dentro(pos):
                    achados.append("a ronda do fantasma %s sai do mapa em %s"
                                   % (fantasma.get("color"), (pos,)))
                    break
        return achados

    def desenhar(self, marcadas=()):
        """Mapa em texto. `marcadas` vira X, para enxergar os becos sem volta."""
        rotulos = {self.pac: "P", self.pilula: "*"}
        for i, casa in enumerate(self.chaves):
            rotulos[casa] = "kmn"[i % 3]
        for i, casa in enumerate(self.portas):
            rotulos[casa] = "DEF"[i % 3]
        for casa in self.portais:
            rotulos.setdefault(casa, "O")
        linhas = []
        for y in range(self.altura):
            linha = []
            for x in range(self.largura):
                casa = (x, y)
                if not self.dentro(casa):
                    linha.append("@")
                elif casa in rotulos:
                    linha.append(rotulos[casa])
                elif casa in self.paredes:
                    linha.append("#")
                elif casa in self.caixotes:
                    linha.append("B")
                else:
                    linha.append("X" if casa in marcadas else ".")
            linhas.append("".join(linha))
        linhas.append("".join(str(x % 10) for x in range(self.largura)))
        return "\n".join(linhas)


def auditar(fase, mostrar_mapa=False, mostrar_becos=False):
    print("=" * 70)
    print(fase.nome)
    for problema in fase.problemas():
        print("  PROBLEMA:", problema)
    solucao = fase.resolver()
    if solucao is None:
        print("  sem solução: a pílula não é alcançável")
    else:
        print("  solução: %d comandos  %s" % (len(solucao), solucao))
    for casa, alternativa in fase.caixotes_necessarios().items():
        print("  caixote %-9s %s" % (
            str(casa) + ":",
            "dispensável: dá para vencer em %d comandos sem movê-lo" % len(alternativa)
            if alternativa else "obrigatório"))
    vistos, vivos = fase.explorar()
    mortos = vistos - vivos
    print("  %d situações alcançáveis, %d sem volta (%.1f%%)"
          % (len(vistos), len(mortos), 100.0 * len(mortos) / len(vistos)))
    # Numa fase com caixotes, beco com todos eles ainda no lugar é falha de
    # desenho: o jogador se perdeu só andando. Depois de um empurrão errado é o
    # risco normal do gênero, e dá para recomeçar a fase no Espaço.
    if fase.caixotes and mortos:
        intacto = tuple(sorted(fase.caixotes))
        antes = [e for e in mortos if e[1] == intacto]
        if antes:
            print("  %d deles já sem mexer em caixote nenhum, com o pac em %s"
                  % (len(antes), sorted({e[0] for e in antes})[:10]))
        else:
            print("  nenhum deles antes de mexer num caixote: só se empurra errado")
    if mostrar_becos:
        presas = {e[0] for e in vistos - vivos}
        sempre = {c for c in presas if all(e[0] != c for e in vivos)}
        print(fase.desenhar(sempre))
        print("  X = casa de onde o pac nunca mais vence, dê qual comando der")
    elif mostrar_mapa:
        print(fase.desenhar())
    return solucao is not None and not fase.problemas()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Resolve e audita fases do Pacmaze.",
        epilog="Sem arquivos, audita toda a campanha em levels/campaign/.")
    parser.add_argument("fases", nargs="*", type=Path,
                        help="arquivos .json de fase")
    parser.add_argument("--mapa", action="store_true", help="desenha o mapa em texto")
    parser.add_argument("--becos", action="store_true",
                        help="desenha o mapa marcando com X as casas sem volta")
    args = parser.parse_args(argv)

    # O console do Windows abre em cp1252 e comeria os acentos da saída.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    caminhos = args.fases or sorted(CAMPAIGN_DIR.glob("*.json"))
    if not caminhos:
        parser.error("nenhuma fase encontrada em %s" % CAMPAIGN_DIR)

    tudo_certo = True
    for caminho in caminhos:
        try:
            fase = Fase.carregar(caminho)
        except (OSError, ValueError, KeyError) as erro:
            print("=" * 70)
            print("%s: não deu para ler (%s)" % (caminho, erro))
            tudo_certo = False
            continue
        tudo_certo &= auditar(fase, args.mapa, args.becos)
    print("\nTodas as fases passaram." if tudo_certo
          else "\nHá fases com problema.")
    return 0 if tudo_certo else 1


if __name__ == "__main__":
    sys.exit(main())
