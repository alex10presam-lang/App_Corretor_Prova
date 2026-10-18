# Corretor de Provas

Correção de provas objetivas com leitura da folha **no próprio celular**. O scanner identifica as marcações, destaca respostas que precisam de conferência e permite revisar a nota antes de salvar.

O reconhecimento usa Dart e a biblioteca `image`. Não envia fotografias a uma API de leitura e não depende de um servidor Python. Login, consulta de provas/alunos e persistência continuam usando Firebase.

## Como usar

1. Gere uma folha nova pelo aplicativo e imprima sem cortar as margens.
2. Leia o QR Code da folha.
3. Fotografe a página inteira, com os quatro quadrados dos cantos visíveis.
4. Confira a foto e as alternativas reconhecidas. Branco, múltiplas marcações e marcas fracas ficam sinalizados.
5. Confirme a revisão, selecione/confirme o aluno e salve.

**Folhas antigas precisam ser geradas novamente.** O modelo `local-v1` tem posições fixas para até 50 questões e cinco alternativas. QRs antigos, de outras versões ou de provas cuja quantidade de questões mudou são recusados. Folhas avulsas sem prova cadastrada podem ser impressas, mas não têm correção automática.

<img src="tests/fixtures/printed_sheet.png" alt="Modelo de folha local com 50 questões" width="360">

## Leitura local

- O gerador de PDF e o leitor compartilham a mesma definição de posições.
- Quatro marcadores permitem corrigir a perspectiva; um padrão adicional identifica a orientação da folha.
- O QR da fotografia é comparado ao QR identificado no início, para evitar troca de prova ou aluno.
- O preenchimento é medido no interior dos círculos, com compensação local de iluminação.
- Imagens com marcadores ausentes, baixa resolução, desfoque intenso ou alinhamento inconsistente são recusadas.
- O processamento roda em um isolate, fora da interface, e pode ser interrompido ao reiniciar ou sair da tela.
- Nenhum resultado é salvo sem conferência. A foto é temporária e não é enviada ao Firebase por este fluxo.

## Estado e validação

34 testes passaram com Flutter 3.35.4 / Dart 3.9.2 e as versões do projeto original. A suíte cobre contrato do QR, 1 a 50 questões, duas colunas, rotação, perspectiva moderada, sombra suave, respostas em branco, múltiplas marcações, marcas parciais, desfoque, arquivos inválidos, cancelamento e leitura de uma imagem renderizada do PDF real.

Os testes usam imagens sintéticas e o PDF real renderizado; **não constituem uma medição de acurácia em fotos de celulares**. Ainda é necessário testar impressões, câmeras e condições reais. A compilação Flutter (`flutter build bundle --debug --no-pub`) passou no projeto completo. A tentativa de gerar o APK neste ambiente foi bloqueada por `Unable to establish loopback connection` no Java/Gradle antes da compilação Android.

## Estrutura

Este repositório preserva a organização original de fontes equivalentes a `lib/`. O projeto Flutter completo foi localizado e usado na validação, mas suas pastas de plataforma e configurações locais não foram importadas para este repositório.

| Arquivo | Responsabilidade |
| --- | --- |
| `scanner/sheet_layout.dart` | Coordenadas e versão do modelo impresso |
| `scanner/scan_contract.dart` | Identidade da prova, aluno, versão e número de questões |
| `scanner/local_omr.dart` | Marcadores, perspectiva e medição das alternativas |
| `services/local_omr_service.dart` | Execução isolada, cancelamento e limite de tempo |
| `services/pdf_service.dart` | Geração da folha compatível |
| `pages/camera_scanner_page.dart` | Câmeras, revisão e confirmação do resultado |
| `tests/` | Testes de contrato, imagem, worker e PDF |

## Testes e integração

Para verificar o scanner isoladamente no Windows, com Flutter instalado:

```powershell
./tool/verify_scanner.ps1
```

Use `-Offline` quando as dependências estiverem no cache. O script monta `.scanner_check/` com as versões usadas na validação; não consulta o Firebase nem chama um serviço externo.

Para aplicar as alterações à pasta do projeto Flutter original:

```powershell
./tool/install_local_scanner.ps1 -ProjectPath 'C:\caminho\corretor_provas'
```

O instalador preserva uma cópia dos arquivos substituídos em `.scanner-backups/`, copia o scanner e seus testes, corrige dois imports quebrados e adiciona as declarações de câmera necessárias. Não altera a configuração do Firebase. A dependência `image` já existe no projeto original; a versão validada é 4.5.4.

Consulte [a documentação do scanner](docs/scanner.md) para os limites, o contrato da folha e o roteiro de teste em aparelho físico.
