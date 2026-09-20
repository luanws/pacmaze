# Pacmaze

Recriação em Godot do Pacmaze, um dos jogos do projeto [Ludum pro bono](https://github.com/lumac-ufsm/ludum-pro-bono-games), originalmente feito em Unity.

O jogador conduz o pac por um labirinto até a pílula branca. Depois que se escolhe uma direção, o pac desliza até bater num obstáculo. No caminho é preciso evitar os fantasmas e usar os portais.

## Controles

| Teclado | Controle | Ação |
| --- | --- | --- |
| Setas | Direcional / analógico esquerdo | Movimentam o pac |
| Seta contra uma porta | Direção contra uma porta | Abre a porta, se o pac tiver a chave da mesma cor |
| `Espaço` | `Y` / triângulo | Volta o pac ao início da fase |
| `Esc` / `P` | `Start` | Pausa |
| `F11` / `Alt+Enter` | | Alterna entre tela cheia e janela |
| `M` | `Select` / `Back` | Liga e desliga o som e a música |

Nos menus, o controle navega com o direcional, confirma com `A` e volta com `B`. O editor de fases precisa de mouse, mas o `B` do controle sai dele e volta ao menu principal. Na versão web, o navegador só reconhece o controle depois que algum botão dele é apertado com a página aberta.

No Windows o jogo abre em tela cheia.

## Fases

Cada fase é um arquivo JSON que o jogo lê e monta ao carregar.

- As fases da campanha ficam em [`levels/campaign/`](levels/campaign/) e são carregadas em ordem alfabética.
- As fases criadas no editor ficam em `user://levels/`. No Windows, essa pasta é `%APPDATA%\Godot\app_userdata\Pacmaze\levels`.

O formato está documentado no topo de [`scripts/level_data.gd`](scripts/level_data.gd). O tamanho vem em `size` (`[colunas, linhas]`) e a borda é sempre o anel externo da grade, então só as paredes de dentro entram no arquivo. As posições são `[coluna, linha]` a partir do canto superior esquerdo:

```json
{
	"format": "pacmaze-level",
	"version": 2,
	"name": "Minha fase",
	"instructions": "",
	"scoring": {"level_bonus":10,"move_sensitivity":200,"time_sensitivity":100},
	"size": [7,4],
	"walls": [
		{"cell":[3,1],"style":"classic"}
	],
	"pushable_walls": [
		{"cell":[4,2],"style":"crate"}
	],
	"player": [1,2],
	"pill": [5,1],
	"ghosts": [
		{"color":"blue","cell":[4,2],"speed":7.5,"path":[[-2,0],[2,0]]}
	],
	"portals": [],
	"locks": [
		{"color":"#00c8ff","key":[1,1],"door":[5,2]}
	]
}
```

- `walls`: as paredes fixas. O `style` escolhe o desenho do bloco (`classic`, `neon`, `red_brick`, `gem`, `metal`, `grass`, `crate`, `ice`, `lava`, `circuit`, `candy`).
- `pushable_walls`: caixotes. Param o pac como qualquer parede, mas se ele encostar num deles parado, o caixote anda uma casa e o pac ocupa o lugar dele — ou seja, empurrar é o único jeito de andar uma casa só, em vez de deslizar até bater. O caixote não sai do lugar se atrás dele houver parede, porta fechada, borda ou outro caixote. Ao reiniciar a fase, todos voltam ao lugar. Como o pac só muda de direção depois de parar, um caixote bem posicionado vira o freio que deixa ele parar na coluna ou linha certa — é essa a ideia das fases 21 a 25.
- `portals`: pares de portais. Entrar em um leva ao outro, e os dois trocam de lugar.
- `locks`: pares de chave e porta. A porta (`door`) bloqueia o pac como uma parede. Passando pela chave (`key`), o pac a guarda, e ela aparece no topo da tela. Para abrir a porta, o pac precisa estar parado ao lado dela e apertar a seta na direção da porta. A chave é gasta, a porta se abre e o pac continua parado até o próximo comando. Quando o pac morre ou volta ao início, as chaves e as portas voltam ao lugar.

### Editor de fases

No menu principal, entre em **Editor de fases**. Lá você desenha paredes, posiciona o pac, a pílula, os fantasmas (com as rotas), os portais e as chaves com suas portas, salva e testa a fase sem sair do jogo. **Salvar** e **Abrir** usam a janela de arquivos do sistema operacional, então a fase pode ficar em qualquer pasta. As fases salvas na pasta padrão (`user://levels/`) aparecem em **Selecionar fase → Fases criadas**.

### Conferindo uma fase sem abrir o jogo

[`tools/level_solver.py`](tools/level_solver.py) simula as regras do jogo (o deslize até bater, o empurrão de caixote, os portais que trocam de lugar, a porta que só abre com a chave) e resolve a fase por busca em largura. Só precisa de Python 3, sem dependências.

```bash
python tools/level_solver.py
```

Sem argumentos ele audita toda a campanha; passando arquivos, audita só eles. De cada fase ele responde:

- **se tem solução** e qual a sequência de comandos mais curta, escrita com `^ v < >`;
- **se cada caixote é mesmo necessário** — ele congela um caixote de cada vez e tenta vencer sem movê-lo;
- **quantos becos sem volta** existem, isto é, situações de onde o jogador já não alcança mais a pílula e precisa reiniciar. Numa fase sem caixotes o normal é zero, e um número alto quase sempre quer dizer que falta uma parede servindo de ponto de parada no caminho de volta. Onde há caixotes, o script separa os dois casos: beco que aparece **antes** de mexer em qualquer caixote é falha de desenho, porque o jogador se perdeu só andando; depois de um empurrão errado é o risco normal do gênero, e para isso existe o `Espaço`;
- **erros de montagem**: pac, pílula, chave, porta ou portal em cima de parede, e rondas de fantasma que saem do mapa ou não fecham o circuito.

Para ver o mapa em texto, com `#` de parede, `B` de caixote e `X` nas casas sem volta:

```bash
python tools/level_solver.py --becos levels/campaign/level_25.json
```

Os fantasmas ficam de fora da busca: eles andam em circuito fixo e o pac pode esperar a hora de passar, então não mudam o que é alcançável.

### Reordenando as fases da campanha

[`tools/renumber_campaign_level.py`](tools/renumber_campaign_level.py) insere uma fase numa posição da campanha e renumera `level_NN.json` em sequência, sem deixar lacunas. Ele abre um seletor de arquivo e pergunta a posição:

```bash
python tools/renumber_campaign_level.py
```

## Rodando o projeto

É preciso o [Godot 4.7](https://godotengine.org/download). Abra a pasta no editor e aperte `F5`, ou rode pela linha de comando:

```bash
godot --path .
```

## Compilando

### Preparação (uma vez só)

1. **Instale os export templates** da mesma versão do editor. No Godot, vá em **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar**. Pela linha de comando, baixe o `.tpz` da [página de downloads](https://godotengine.org/download/archive/) e instale pelo mesmo menu com **Instalar do Arquivo**.
2. **Crie os presets de exportação** em **Projeto → Exportar… → Adicionar…**:
   - **Windows Desktop**
	 - Marque **Embed PCK** para gerar um `.exe` único.
   - **Web**
	 - Desmarque **Thread Support**. Assim o jogo roda em qualquer servidor estático, sem os cabeçalhos COOP/COEP.
   - Nos dois presets, em **Recursos → Filtros para exportar arquivos que não são recursos**, coloque `levels/*.json`. Isso garante que as fases da campanha entram no pacote.

   Os presets ficam salvos em `export_presets.cfg`, que pode ser versionado.

Os comandos abaixo usam os nomes exatos dos presets (`"Windows Desktop"` e `"Web"`). Se você renomear algum, ajuste os comandos. Deixe a pasta `build/` fora do git: adicione `/build/` ao `.gitignore`.

### Windows

```bash
mkdir -p build/windows
```

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Pacmaze.exe
```

Para uma versão com console e depuração, troque `--export-release` por `--export-debug`.

### Web

```bash
mkdir -p build/web
```

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

O jogo web não abre direto do arquivo (`file://`); ele precisa de um servidor HTTP. Para testar localmente:

```bash
python -m http.server 8000 --directory build/web
```

Depois acesse <http://localhost:8000>. Para publicar, envie o conteúdo de `build/web/` para qualquer hospedagem estática (GitHub Pages, itch.io, Netlify…).

### Publicação automática no GitHub Pages

O workflow [`.github/workflows/pages.yml`](.github/workflows/pages.yml) compila a versão web e publica no GitHub Pages a cada push na `main`. Também dá para rodá-lo à mão pela aba **Actions**. Para ele funcionar, é preciso configurar o repositório uma vez: em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions**.

O jogo fica em <https://luanws.github.io/pacmaze/>.

Diferenças na versão web:

- O botão **Sair** não aparece no menu.
- No editor de fases, **Salvar** e **Abrir** usam a janela de arquivos do sistema, através do navegador:
  - No Chrome e no Edge você escolhe a pasta e o nome do arquivo. Os próximos **Salvar** gravam no mesmo arquivo sem perguntar de novo.
  - Nos outros navegadores, **Salvar** baixa o `.json` para a pasta de downloads.
  - Uma cópia de cada fase salva também fica no armazenamento do navegador. Assim ela aparece em **Selecionar fase → Fases criadas**.

## Créditos

- A música e os efeitos sonoros são sintetizados pelo próprio jogo, em [`scripts/sfx.gd`](scripts/sfx.gd).
- As imagens da chave e do cadeado (`assets/sprites/key.png` e `assets/sprites/lock.png`) são dos pacotes *Game Icons* e *Game Icons Expansion*, da [Kenney](https://kenney.nl), publicados sob a licença [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
