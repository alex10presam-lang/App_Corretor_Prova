# Scanner local

## Contrato da folha

O layout `local-v1` aceita 1 a 50 questões em uma página A4, com alternativas A a E. As posições estão em `scanner/sheet_layout.dart` e são usadas pelo PDF e pelo reconhecimento. Não altere as coordenadas sem incrementar a versão do modelo e atualizar as imagens de regressão.

O QR contém apenas identificação, nunca o gabarito:

```json
{"layout":"local-v1","provaId":"demo-local","questions":50,"totalPages":1}
```

Folhas personalizadas incluem `alunoId` e `turmaId` juntos. O scanner valida o QR inicial, verifica a quantidade atual da prova e exige que o QR visível na fotografia tenha a mesma identidade. A geometria não suporta folhas antigas ou multipágina. Modelos avulsos sem prova cadastrada não recebem QR de correção.

## Pipeline

1. Decodifica a foto, respeita a orientação EXIF e limita a dimensão maior a 1600 pixels.
2. Converte a imagem em luminância e usa limiar local para procurar componentes escuros compatíveis com os marcadores.
3. Seleciona candidatos nos quatro cantos e exige que a folha ocupe uma área mínima da imagem.
4. Ajusta uma transformação projetiva e procura o padrão assimétrico de orientação.
5. Amostra o interior das bolhas, usando a região ao redor para estimar o papel e compensar variações suaves de iluminação.
6. Confere o contraste das bordas impressas para detectar desalinhamento ou desfoque acentuado.
7. Retorna alternativas e índices que exigem revisão; nunca calcula uma probabilidade estatística de acerto.

Respostas: `0..4` = A..E; `-1` = branco/não determinado; `-2` = mais de uma alternativa preenchida. Marcas fracas não viram acertos por aproximação: são sinalizadas para revisão. Mesmo uma leitura sem alertas exige confirmação antes de salvar.

O trabalho ocorre em um isolate, com limite de 30 segundos. Reiniciar ou sair cancela o trabalho. O scanner libera a câmera QR antes de abrir a câmera fotográfica, prefere a lente traseira e ignora respostas de sessões antigas. A foto temporária é removida após o fluxo e não é enviada ao servidor de OMR nem ao Firebase pelo scanner.

## O que ainda usa internet

A leitura das marcações e do QR não exige servidor. Autenticação, carregamento dos dados da prova/aluno e salvamento mantêm a integração Firebase existente. O acesso sem rede a esses dados depende do cache do SDK; esta alteração não implementa um banco offline completo nem uma fila de sincronização própria.

## Verificação executada

- 34 testes automatizados passaram com Flutter 3.35.4 / Dart 3.9.2.
- Testes cobrem leitura e falhas, incluindo folha em duas colunas, rotações de 90/180/270 graus, perspectiva moderada, sombra suave, múltiplas marcações, branco, marca parcial e cancelamento.
- A imagem `tests/fixtures/printed_sheet.png` foi renderizada do PDF emitido pelo gerador real. O teste lê a folha vazia e a mesma imagem com 50 marcações conhecidas.
- O PDF de 50 questões foi inspecionado visualmente: sem sobreposição ou recorte dos círculos, QR, textos e marcadores.
- A compilação da parte Flutter do projeto completo passou (`flutter build bundle --debug --no-pub`).
- A compilação Android ficou bloqueada por uma falha do ambiente Java/Gradle: `java.io.IOException: Unable to establish loopback connection`, causada por `SocketException: Invalid argument: connect` em `UnixDomainSockets.connect0`. Não foi produzido um APK validado nesta execução.

## Validação física pendente

Use dados fictícios antes de utilizar notas reais:

- Imprima folhas de 10, 25 e 50 questões, verificando se os quatro marcadores saem inteiros.
- Teste diferentes impressoras, câmeras, caneta azul/preta e iluminação.
- Meça respostas corretas, leituras recusadas e erros por questão; não use apenas a nota final como métrica.
- Teste inclinação, rotação, tremor, rasura, sombra forte, brilho e folha dobrada.
- Confirme que marcas fracas, brancos e múltiplas marcações pedem conferência.
- Troque a folha entre a leitura do QR e a foto: o scanner deve rejeitar a troca.
- Interrompa durante abertura da câmera, foto, leitura e revisão; retorne e reinicie.
- Negue a câmera e depois permita nas configurações do aparelho.
- Teste confirmação do aluno e falhas do Firebase. Consulte os resultados antes de repetir um salvamento cuja confirmação falhou, pois o serviço existente ainda cria documentos sem uma chave de idempotência.

As fotos sintéticas não substituem essa validação. Perspectiva extrema, reflexos, sombras duras, dobras e preenchimento muito leve podem exigir nova fotografia ou ajuste manual.

## Integração reversível

`tool/install_local_scanner.ps1` exige o `pubspec.yaml` do projeto original. O backup inclui os arquivos substituídos e `manifest.json`, que registra quais arquivos já existiam. Para desfazer, restaure os arquivos do backup e remova somente os arquivos novos indicados pelo manifesto. Preserve mudanças posteriores antes de restaurar.

Referências: [Dart image](https://pub.dev/packages/image), [ciclo de vida da câmera](https://pub.dev/packages/camera#handling-lifecycle-states) e [mobile_scanner](https://pub.dev/packages/mobile_scanner). O projeto foi testado com `image 4.5.4`, `camera 0.10.6` e `mobile_scanner 5.2.3`.
