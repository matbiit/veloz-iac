# ADR-002 — Política de mudanças em produção

- **Status:** proposto (decidido ao vivo com a turma no Bloco 1)
- **Data:** 2026-11
- **Decisores:** CTO, Head de Plataforma, Segurança da Informação, Head de Produto
- **Gatilho:** Black Friday em 27/11/2026 e quatro incidentes ligados a mudanças manuais

## Contexto

- Pulsar: ambientes criados à mão, com drift; um patch passou em homologação e quebrou produção.
- Axion Data: tfstate trocado por e-mail e corrompido duas vezes; bucket de clientes público por dias.
- GHS: 15% dos servidores fora do padrão de segurança numa auditoria.
- VeloZ: ajuste manual de rede no cluster derrubou a loja por 2 horas, sem trilha de auditoria.
- Lição de mercado: na queda da AWS em us-east-1 (out/2025), uma automação sem proteção contra planos incorretos gravou um DNS vazio. Automatizar não basta: a automação precisa de guarda-corpos.

## Opções consideradas

| Opção | Velocidade em emergência | Auditoria | Risco de drift | Esforço de adoção |
|---|---|---|---|---|
| A. Console liberado, com registro em ticket | alta | fraca (depende de disciplina) | alto | nenhum |
| B. Só via pull request + pipeline, com *break-glass* auditado | média | forte | baixo | médio |
| C. Só via pull request, sem exceção | baixa em incidente grave | forte | baixo | médio |

## Decisão

**Opção B.** Toda mudança de infraestrutura entra por pull request e é aplicada pelo pipeline.
O acesso de emergência (*break-glass*) existe, mas é temporário, auditado e caro de usar.

## Regras

1. Ninguém tem credencial de escrita em produção no laptop; quem aplica é o pipeline (OIDC, sem chave fixa).
2. Todo PR passa por: `fmt`, `validate`, `tflint`, `checkov`, `conftest` (políticas da empresa) e plan comentado.
3. `CODEOWNERS`: dados exigem aprovação de Dados + Segurança; módulos exigem Plataforma.
4. Break-glass: acesso de no máximo 2 horas, 2 aprovadores, sessão gravada, e a mudança precisa ser reconciliada no código em até 24 horas (senão o próximo `plan` desfaz).
5. Exceções a políticas (`#checkov:skip`) só com justificativa de negócio e referência a um ADR.
6. Kubernetes em modelo pull (ArgoCD/Flux) com `selfHeal`: mudança manual no cluster é revertida.

## Consequências

- (+) Trilha de auditoria completa: quem mudou, o quê, quando e quem aprovou.
- (+) Rollback vira `git revert`.
- (−) Primeira semana mais lenta: times precisam aprender o fluxo de PR para infraestrutura.
- (−) Break-glass precisa ser testado (um game day por trimestre), ou vai falhar quando for necessário.

## Como vamos medir (revisão mensal)

| Indicador | Hoje | Meta T1/2027 |
|---|---|---|
| Tempo para criar ambiente de teste | semanas | < 10 min |
| Mudanças em produção fora do Git | desconhecido | 0 (fora o break-glass auditado) |
| Recursos sem tags de custo | desconhecido | 0% |
| Detecção de drift | auditoria anual | diária (`plan -detailed-exitcode`, `ansible --check`) |
