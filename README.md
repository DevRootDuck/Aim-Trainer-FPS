# Aim Trainer FPS — v3 (reconstrução completa)

Projeto **100% original**: personagens (Adão e Eva), arma (AX-9), mapa,
sons, HUD e mira são todos gerados **proceduralmente por código**
(geometria via primitivas, áudio via síntese de onda) — nada foi copiado
de nenhum jogo existente.

## Como abrir

1. Abra a pasta `AimTrainerFPS` no **Godot 4.3+**.
2. Rode a cena `scenes/menus/MainMenu.tscn` (já é a cena inicial do projeto).
3. **Eu não tenho um editor Godot neste ambiente para testar** — revisei o
   código com cuidado, mas se aparecer algum erro ao abrir/rodar, me
   mande a mensagem exata do console que eu corrijo rapidamente.

## Controles

| Ação | Tecla |
|---|---|
| Mover | W A S D |
| Pular | Espaço |
| Correr | Shift |
| Agachar | Ctrl |
| Atirar | Botão esquerdo do mouse (segure para automático) |
| Recarregar | R |
| Pausar | ESC |

## O que já está implementado

- **Câmera/movimento**: mouse travado e ativo desde o início, 360°,
  aceleração/desaceleração, head bob, lean ao correr, FOV dinâmico, pulo,
  agachar, corrida — tudo suave.
- **Tiro**: hitscan, recoil, spray, bloom, flash do cano, faíscas de
  impacto, hitmarker, indicador de HEADSHOT, munição (30 balas) e recarga.
- **Arma AX-9**: modelo original construído por primitivas, com sway/bob
  ao andar e kick de recoil.
- **Personagens Adão e Eva**: corpo procedural (cabeça/tronco/braços/
  pernas), animação de caminhar/correr, flash vermelho ao levar dano,
  animação de "morte" ao serem eliminados.
- **IA dos alvos**: aparecem em posição aleatória, andam, correm, agacham,
  pulam ocasionalmente e podem se esconder atrás de pilares/caixas/barris.
- **Arena**: área aberta + área fechada + corredor + rampa + plataforma
  com escada + pilares + caixas + barris em distâncias variadas — tudo
  gerado por código.
- **9 modos de treino**: Livre, Estáticos, Aleatórios, Móveis, Reflexo,
  Sobrevivência, Headshot Only, Precisão, Cronometrado.
- **HUD**: crosshair, munição, FPS, tempo, precisão, headshots, kills,
  tempo médio de reação, modo atual.
- **Menu Principal**, **Pause** (Continuar/Configurações/Reiniciar/Menu/
  Sair) e **Tela de Resultados**, todos com transições suaves.
- **Configurações completas** (mouse, áudio, vídeo, interface), aplicadas
  em tempo real e salvas em `user://save/settings.cfg`.
- **Editor de Mira completo**: tipo, cor, tamanho, espessura, gap,
  opacidade, outline, ponto central, comportamento dinâmico (expandir ao
  atirar/correr/pular), pré-visualização instantânea, presets
  salvar/carregar/excluir/importar/exportar (JSON).
- **Seleção de Personagem**: Eva e Adão girando em um preview 3D, com
  nome e descrição.
- **Áudio 100% original**: todos os efeitos (tiro, impacto, headshot,
  recarga, passos, hitmarker, clique de UI) e a música ambiente são
  sintetizados por código — nenhum arquivo de áudio externo foi usado.
- **Otimizações**: geometria com `visibility_range`, poucas luzes
  dinâmicas, qualidade de sombra/textura/AA ajustável, presets de
  qualidade Baixo/Médio/Alto pensados para hardware modesto (testado
  mentalmente para não pesar em GPUs como a R5 230 — mas recomendo
  começar no preset "Baixo/Médio" e ajustar).
- **Organização**: `autoload/` (singletons), `scripts/` (por categoria:
  player, weapons, characters, targets, arena, ui, menus, results,
  effects), `scenes/` (espelhando scripts), `assets/` (pastas prontas
  para receber modelos/texturas/áudio reais no futuro), `resources/`,
  `save/`, `shaders/`.

## Simplificações conscientes (para você saber e evoluir depois)

- **Modelos 3D**: personagens e arma são feitos de primitivas (cápsulas,
  caixas, cilindros) geradas em código, não modelados/esculpidos/UV-
  mapeados num software 3D. Ficam leves e sem risco de copyright, mas
  visualmente simples. Dá pra trocar por modelos importados (.glb) mais
  tarde — é só ajustar `_build_model()`/`_build_body()`.
- **Áudio**: sintetizado por código (ondas simples), não gravado/mixado
  profissionalmente. Fica 100% original e leve, mas o timbre é mais cru
  que um efeito sonoro produzido à mão.
- **Multiplayer/contas/ranking**: fora do escopo desta entrega (é um
  projeto à parte). A UI de configurações já tem um "Mostrar Ping"
  preparado para quando isso existir, e o código está organizado em
  módulos (autoloads/scripts separados) para facilitar adicionar depois.
- **Pausa**: implementada com uma flag lógica (`GameManager.GameState.
  PAUSED`) em vez do pause nativo do Godot (`get_tree().paused`), para
  evitar armadilhas de herança de `process_mode` entre os muitos nós da
  cena. Isso funciona bem, mas os timers dos alvos continuam contando
  em segundo plano enquanto pausado (eles só não são visíveis/atingíveis
  nesse momento) — um possível polimento futuro.
- **Skins/contas/atualizações**: a estrutura de pastas e o
  `CrosshairManager`/`SettingsManager` já seguem o padrão de "sistema com
  presets salvos em JSON", então adicionar skins ou contas no futuro
  segue o mesmo molde.

## Multiplayer Coop (novo)

Jogue com 2-50 amigos no mesmo treino, por IP direto:

- No Menu Principal, **"Jogar Online (Coop)"**.
- **Host**: aba "Criar Grupo" → escolhe mapa/modo/dificuldade/limite de
  jogadores → "Criar Grupo". O jogo detecta seu IP público sozinho
  (via `api.ipify.org`) e gera um **Código do Grupo de 6 caracteres**.
  Manda esse código pros seus amigos (Discord, WhatsApp, etc.).
- **Amigos**: aba "Entrar em Grupo" → colam o código → "Entrar".
- Na sala de espera, o host vê todo mundo conectado e clica em
  "Iniciar Partida" quando quiser começar — todo mundo entra na mesma
  arena, vê os alvos e os colegas de equipe se movendo, e tem sua
  própria contagem de precisão/kills/headshots.

**Importante sobre o Código do Grupo**: ele só codifica o seu IP — não
é um servidor de matchmaking de verdade. Isso significa que, pra
amigos de fora da sua rede conseguirem entrar, **você (host) ainda
precisa liberar a porta 8910 (UDP/TCP) no seu roteador** (port
forwarding) apontando pro seu computador. Sem isso, só funciona com
quem estiver na mesma rede Wi-Fi/LAN que você.

**Limite de jogadores**: o slider vai até 50, mas isso é o limite
técnico do Godot — na prática, uma conexão residencial normal aguenta
bem uns 8-16 jogadores num FPS. Acima disso, sua própria internet
(upload) vira o gargalo, já que o host recebe/retransmite todo o
tráfego de validação.

**Como funciona por baixo dos panos** (caso quiser mexer): o host é
sempre a autoridade — só ele decide onde/quando os alvos aparecem e
valida quem acertou o tiro primeiro (evita dois jogadores "matarem" o
mesmo alvo ao mesmo tempo). Cada cliente faz seu próprio raycast
localmente (pra mira responder na hora) e manda um pedido de
confirmação pro host; isso é ótimo pra jogar com amigos, mas **não
tem proteção anti-cheat** — para o PvP (que você pediu pra depois),
vale a pena o host validar a geometria do tiro também, não só "quem
pediu primeiro".

**PvP**: ainda não implementado (combinamos de fazer depois do coop).
A arquitetura de rede já está pronta pra isso — dá pra reaproveitar as
Hurtboxes dos personagens (hoje só usadas nos alvos) pra tornar os
próprios jogadores alvos uns dos outros, adicionando vida/respawn/
placar.

**Simplificações desta primeira versão do multiplayer**:
- Sem reconexão: se alguém cair no meio da partida, não tem como
  voltar pra mesma sessão (precisa criar/entrar de novo).
- Sem lista pública de salas — é só "host cria, avisa o código".
- O fim do cronômetro do treino é decidido de forma independente por
  cada jogador (todos começam sincronizados, mas variações de FPS/
  latência podem fazer alguém terminar meio segundo antes/depois dos
  outros).
- Só existe um mapa por enquanto (a seleção de mapa na tela de criar
  grupo já está pronta pra quando houver mais de um).

## Testando você mesmo

Como não tenho o editor aqui, a forma mais rápida de achar qualquer
problema é: abra o projeto, rode `MainMenu.tscn`, clique em "Jogar" e
teste um treino completo. Qualquer erro que aparecer no console de saída
do Godot, me manda o texto completo que eu já corrijo.
