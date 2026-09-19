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

Nos menus, o controle navega com o direcional, confirma com `A` e volta com `B`. Na versão web, o navegador só reconhece o controle depois que algum botão dele é apertado com a página aberta.

No Windows o jogo abre em tela cheia.

## Fases

Cada fase é um arquivo JSON que o jogo lê e monta ao carregar.

- As fases da campanha ficam em [`levels/campaign/`](levels/campaign/) e são carregadas em ordem alfabética.
- As fases criadas no editor ficam em `user://levels/`. No Windows, essa pasta é `%APPDATA%\Godot\app_userdata\Pacmaze\levels`.

O formato está documentado no topo de [`scripts/level_data.gd`](scripts/level_data.gd). No mapa, `+` é um bloco de borda, `#` é parede e `.` é vazio. As posições são `[coluna, linha]` a partir do canto superior esquerdo:

```json
{
	"format": "pacmaze-level",
	"version": 1,
	"name": "Minha fase",
	"instructions": "",
	"scoring": {"level_bonus":10,"move_sensitivity":200,"time_sensitivity":100},
	"map": [
		"+++++++",
		"+..#..+",
		"+.....+",
		"+++++++"
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

- `portals`: pares de portais. Entrar em um leva ao outro.
- `locks`: pares de chave e porta. A porta (`door`) bloqueia o pac como uma parede. Passando pela chave (`key`), o pac a guarda, e ela aparece no topo da tela. Para abrir a porta, o pac precisa estar parado ao lado dela e apertar a seta na direção da porta. A chave é gasta, a porta se abre e o pac continua parado até o próximo comando. Quando o pac morre ou volta ao início, as chaves e as portas voltam ao lugar.

### Editor de fases

No menu principal, entre em **Editor de fases**. Lá você desenha paredes, posiciona o pac, a pílula, os fantasmas (com as rotas), os portais e as chaves com suas portas, salva e testa a fase sem sair do jogo. **Salvar** e **Abrir** usam a janela de arquivos do sistema operacional, então a fase pode ficar em qualquer pasta. As fases salvas na pasta padrão (`user://levels/`) aparecem em **Selecionar fase → Fases criadas**.

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
