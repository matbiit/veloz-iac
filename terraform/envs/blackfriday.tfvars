# Ambiente efêmero de teste de carga para a Black Friday (27/11/2026).
# Sobe na segunda, roda o teste de carga, e é DESTRUÍDO na sexta com `destroy`.
ambiente           = "blackfriday"
replicas_vitrine   = 4
porta_base         = 9080
memoria_vitrine_mb = 256
