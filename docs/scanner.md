# Scanner: contrato e validação

## Contrato existente preservado

Requisição `POST` em HTTPS, `multipart/form-data`:

| Campo | Conteúdo |
| --- | --- |
| `file` | Foto JPEG da folha inteira |
| `expected_questions` | Número de questões da prova em página única |

Resposta HTTP 200:

```json
{"answers": [0, 1, 2, 3, 4, -1, -2]}
```

A lista deve ter exatamente `expected_questions` entradas. Valores inteiros `0..4` correspondem a A..E; `-1` representa questão em branco; `-2`, múltiplas marcações, conforme o validador existente. Strings, números decimais, valores fora desse domínio e listas incompletas são rejeitados. O cliente não adiciona respostas ausentes nem corta respostas excedentes.

A API precisa ser confirmada com seu código Python: a implementação não está neste repositório. Em 17/10/2026, uma requisição HEAD sem imagem ao endereço configurado retornou HTTP 500. Isso não valida o comportamento de POST nem a disponibilidade permanente do serviço.

O gerador atual emite `totalPages: 1` no QR. O campo `questoesPorPagina` do modelo não controla esse gerador. O scanner usa o número real de questões da folha, não o antigo limite fixo de 25. A aceitação desse número e a geometria das bolhas precisam ser confirmadas no servidor. Folhas antigas com várias páginas são recusadas até haver um contrato que identifique cada página.

## Câmera e interrupções

O leitor QR permanece montado, com início automático desativado. Uma fila serializa abertura, parada e liberação de câmeras. A fotografia é inicializada somente depois de parar o QR. Erros de flash não impedem fotografar.

Ao colocar o app em segundo plano, as câmeras são liberadas e o upload é cancelado. Ao voltar, uma captura interrompida recomeça pela identificação do QR. Uma revisão já aberta mantém suas alternativas. Cada sessão possui uma geração; consultas e respostas de sessões anteriores são ignoradas.

## Testes em aparelho físico ainda necessários

Use alunos e folhas fictícios em um ambiente de desenvolvimento.

- Conceder e negar permissão de câmera; retornar das configurações após concedê-la.
- Ler QR válido, desconhecido e de aluno removido; verificar recuperação sem reiniciar o app.
- Alternar QR/fotografia repetidamente; testar câmera traseira e aparelho sem flash.
- Colocar em segundo plano durante consulta da prova, captura, upload e revisão.
- Reiniciar durante upload; confirmar que uma resposta antiga não abre resultados.
- Fotografar folhas de 10, 25 e mais de 25 questões, com branco e múltipla marcação.
- Testar sombras, perspectiva e desfoque com alternativas conhecidas; medir acurácia por questão.
- Desligar a rede e provocar erro/timeout do servidor; tentar novamente.
- Comparar foto, respostas e nota; alterar uma alternativa e confirmar o recálculo.
- Cancelar seleção de aluno; simular falha de Storage/Firestore; verificar preservação das respostas.
- Conferir permissões de câmera e internet das plataformas e configuração Firebase original.

## Limites conhecidos

- Sem o projeto completo, não há build Android/iOS nem validação de permissões nativas.
- Os testes automatizados simulam transporte e respostas; não medem reconhecimento óptico.
- O salvamento existente usa upload seguido de criação de documento. Uma falha de confirmação pode ser ambígua; consulte os resultados antes de repetir. Não foi implementada transação entre Storage e Firestore.
- O layout do PDF e o algoritmo OMR não foram redesenhados sem acesso ao servidor. A compatibilidade entre eles é uma pendência de integração.

Referências de implementação: [ciclo de vida do camera](https://pub.dev/packages/camera#handling-lifecycle-states), [mobile_scanner](https://pub.dev/packages/mobile_scanner), [HTTP Client](https://pub.dev/documentation/http/latest/http/Client-class.html). A verificação local fixa as versões no manifesto de teste, sem presumir as versões do aplicativo original.
