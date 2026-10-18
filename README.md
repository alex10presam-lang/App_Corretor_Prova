# Corretor de Provas

Aplicativo Flutter para organizar turmas, gerar folhas de resposta e revisar correções de provas objetivas. Usa Firebase para autenticação e armazenamento, e um serviço HTTP externo para ler as marcações da folha (OMR).

## Estado do repositório

Este repositório contém os arquivos que compõem a pasta `lib/` do aplicativo. O projeto Flutter completo (`pubspec.yaml`, `android/`, `ios/`) e o servidor Python de leitura **não estão incluídos**. Por isso, esta cópia não gera um aplicativo instalável por conta própria.

A atualização do scanner corrige o fluxo no cliente. A precisão do reconhecimento e a execução em aparelho físico ainda precisam de validação com o serviço real.

## Fluxo de correção

1. Leia o QR Code da folha gerada pelo aplicativo.
2. Enquadre a folha inteira, mantendo os quatro marcadores visíveis.
3. Fotografe e aguarde a análise.
4. Compare as alternativas reconhecidas com a foto e ajuste eventuais erros de leitura.
5. Confirme o aluno e salve a correção.

Nenhuma nota é salva automaticamente após a captura. Respostas incompletas ou fora do formato esperado são rejeitadas antes do cálculo.

## O que mudou no scanner

- Liberação explícita da câmera entre a leitura do QR e a fotografia; preferência pela câmera traseira.
- Cancelamento da comunicação ao reiniciar ou sair da tela; respostas antigas não atualizam uma nova leitura.
- Limite de 45 segundos para envio e recebimento da análise, com mensagens para erros de rede e HTTP.
- Envio do número integral de questões da folha. A versão anterior limitava a requisição a 25, mesmo quando o PDF continha mais questões.
- Conferência e ajuste das alternativas antes de salvar, com foto e nota calculada.
- Preservação das respostas no diálogo quando o salvamento falha e remoção da foto temporária ao encerrar o fluxo.

O gerador atual declara uma página por aluno. QRs com várias páginas são recusados explicitamente: faltam identificação individual e um contrato de paginação com o servidor para impedir duplicação ou troca de folhas. Isso substitui a montagem anterior, que podia completar leituras ausentes com respostas em branco.

## Organização

| Local | Responsabilidade |
| --- | --- |
| `pages/camera_scanner_page.dart` | Câmera, estados da tela e revisão da correção |
| `scanner/scan_contract.dart` | Validação do QR e das respostas reconhecidas |
| `services/omr_service.dart` | Upload, prazo de resposta e erros do serviço |
| `services/pdf_service.dart` | Geração das folhas |
| `services/resultado_service.dart` | Persistência no Firebase |
| `tests/scanner_test.dart` | Contrato e cenários de falha de comunicação |

## Verificação isolada

Com Flutter instalado, execute no PowerShell:

```powershell
./tool/verify_scanner.ps1
```

Use `-Offline` se as dependências já estiverem no cache. O script copia apenas o scanner e suas dependências locais para `.scanner_check/`, resolve versões declaradas em `tool/scanner_pubspec.yaml`, executa análise estática e testes. Não consulta o Firebase nem envia fotos ao servidor real.

Esse ambiente é um teste isolado, não uma reconstrução do projeto original. As versões escolhidas para a verificação precisam ser conciliadas com o `pubspec.yaml` original antes da integração.

## Integração e pendências

Copie os arquivos alterados para os mesmos caminhos dentro de `lib/` do projeto completo. Preserve a configuração existente de Firebase e das plataformas. O scanner requer as dependências `camera`, `mobile_scanner`, `http` e `http_parser`, além das dependências já usadas pelos serviços do app.

O endereço pode ser configurado na compilação:

```sh
flutter run --dart-define=OMR_API_URL=https://seu-servico.example/processar
```

Sem essa opção, permanece o endereço anteriormente configurado no código. Veja [o contrato HTTP e o roteiro de validação](docs/scanner.md) antes de integrar a alteração.
