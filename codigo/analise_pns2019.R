#### TRABALHO FINAL - ECONOMETRIA - 2026.1
#### Letícia Fonseca Pereira


### 1. INSTALAÇÃO DE PACOTES (caso não estejam instalados)
install.packages("tidyverse")
install.packages("PNSIBGE")
install.packages("survey")
install.packages("srvyr")
install.packages("stargazer")


### 2. CARREGAMENTO DE PACOTES
library(tidyverse)
library(PNSIBGE)
library(survey)
library(srvyr)
library(stargazer)


### 3. CARREGAMENTO DOS MICRODADOS - PNS 2019
pns_bruto <- get_pns(year = 2019, selected = TRUE, design = TRUE)

# verificação dos níveis das variáveis utilizadas
summary(pns_bruto$variables$J012) # número de consultas médicas no ano
levels(pns_bruto$variables$Q092) # diagnóstico de depressão (binária)
levels(pns_bruto$variables$C006) # gênero
summary(pns_bruto$variables$C008) # idade
levels(pns_bruto$variables$VDD004A) # instrução
levels(pns_bruto$variables$C009) # raça/cor


### 4. LIMPEZA E CONSTRUÇÃO DE VARIÁVEIS
pns_vars <- pns_bruto$variables %>%
  mutate(
    num_consultas_bruto = as.numeric(as.character(J012)), # variável dependente
    num_consultas = case_when(
      num_consultas_bruto == 999 ~ NA_real_,
      is.na(num_consultas_bruto) ~ 0,
      TRUE ~ num_consultas_bruto
    ),
    depressao = case_when( # variável independente principal
      as.character(Q092) == "Sim" ~ 1,
      as.character(Q092) == "Não" ~ 0,
      TRUE ~ NA_real_
    ),
    feminino = case_when( # controle 1 
      as.character(C006) == "Mulher" ~ 1,
      as.character(C006) == "Homem"  ~ 0,
      TRUE ~ NA_real_
    ),
    idade = as.numeric(C008), # controle 2
    instrucao = relevel(as.factor(VDD004A), ref = "Sem instrução"), # controle 3
    raca_cor = as.character(C009), # controle 4 / temporariamente como string
    renda_pc = as.numeric(VDF003), # controle 5
    log_renda = log(renda_pc + 1) # controle 6
  ) %>%
  
  filter(
    raca_cor != "Ignorado",
    idade >= 18,
    !is.na(num_consultas),
    !is.na(depressao),
    !is.na(feminino),
    !is.na(instrucao),
    !is.na(renda_pc)
  ) %>%
  
  mutate(
    raca_cor = relevel(droplevels(as.factor(raca_cor)), ref = "Branca")
  )

cat("N após filtros:", nrow(pns_vars), "\n") # verificação

pns_desenho <- svydesign(
  ids = ~UPA_PNS, # unidade primária de amostragem
  strata = ~V0024, # estrato
  weights = ~V00291, # peso do morador selecionado
  data = pns_vars,
  nest = TRUE # UPAs não são únicas entre estratos
) %>% as_survey()


### 5. TABELA 1 - Estatísticas descritivas dos X
cat("\nESTATÍSTICAS DESCRITIVAS DAS VARIÁVEIS EXPLICATIVAS\n")

cat("\n1. Variável feminino (dummy)\n")
svymean(~feminino, pns_desenho, na.rm = TRUE)
p_fem <- coef(svymean(~feminino, pns_desenho, na.rm = TRUE))
sqrt(p_fem * (1 - p_fem))

cat("\n2. Variáveis instrução (dummies)\n") # todas as categorias, inclusive a de referência
svymean(~instrucao, pns_desenho, na.rm = TRUE)
p_instr <- coef(svymean(~instrucao, pns_desenho, na.rm = TRUE))
sqrt(p_instr * (1 - p_instr)) # vetor com o desvio padrao de cada categoria

cat("\n3. Variáveis raça/cor (dummies)\n") # todas as categorias, inclusive a de referência
svymean(~raca_cor, pns_desenho, na.rm = TRUE)
p_raca <- coef(svymean(~raca_cor, pns_desenho, na.rm = TRUE))
sqrt(p_raca * (1 - p_raca))

cat("\n4. Variável idade (contínua)\n")
svymean(~idade, pns_desenho, na.rm = TRUE) # média + erro padrão
sqrt(coef(svyvar(~idade, pns_desenho, na.rm = TRUE))) # desvio padrão ponderado
range(pns_desenho$variables$idade, na.rm = TRUE) # min e max

cat("\n5. Variável log_renda (contínua)\n")
svymean(~log_renda, pns_desenho, na.rm = TRUE)
sqrt(coef(svyvar(~log_renda, pns_desenho, na.rm = TRUE)))
sqrt(coef(svyvar(~renda_pc, pns_desenho, na.rm = TRUE))) # desv. padrão em reais
range(pns_desenho$variables$log_renda, na.rm = TRUE)


### 6. TABELA 2 - estatísticas descritivas de Y em relação a X
cat("\nESTATÍSTICAS DESCRITIVAS DA VARIÁVEL DEPENDENTE (em relação aos X)\n")

n_real <- pns_desenho %>% summarize(total = unweighted(n()))
cat("\n1. N amostral real:", n_real$total, "\n") # = linhas completas depois dos filtros

cat("\n2. Média geral do número de consultas no ano:\n")
svymean(~num_consultas, pns_desenho, na.rm = TRUE)

cat("\n3. Média de consultas médicas por status de diagnóstico de depressão:\n")
descritiva_depressao <- pns_desenho %>%
  group_by(depressao) %>%
  summarize(
    proporcao_populacao = survey_mean(),
    media_consultas = survey_mean(num_consultas, na.rm = TRUE),
    n_bruto = unweighted(n())
  ) %>%
  mutate(status_depressao = ifelse(depressao == 0, "Sem depressão", "Com depressão"))
print(descritiva_depressao)

cat("\n4. Estatísticas descritivas por gênero:\n")
descritiva_genero <- pns_desenho %>%
  group_by(feminino) %>%
  summarize(
    proporcao_populacao = survey_mean(),
    prev_depressao = survey_mean(depressao, na.rm = TRUE),
    media_consultas = survey_mean(num_consultas, na.rm = TRUE),
    n_bruto = unweighted(n())
  ) %>%
  mutate(genero = ifelse(feminino == 0, "Masculino", "Feminino"))
print(descritiva_genero)

cat("\n5. Estatísticas descritivas por nível de instrução:\n")
descritiva_instrucao <- pns_desenho %>%
  group_by(instrucao) %>%
  summarize(
    proporcao_populacao = survey_mean(),
    prev_depressao = survey_mean(depressao, na.rm = TRUE),
    media_consultas = survey_mean(num_consultas, na.rm = TRUE),
    n_bruto = unweighted(n())
  )
print(descritiva_instrucao)

cat("\n6. Estatísticas descritivas por raça/cor:\n")
descritiva_raca <- pns_desenho %>%
  group_by(raca_cor) %>%
  summarize(
    proporcao_populacao = survey_mean(),
    prev_depressao = survey_mean(depressao, na.rm = TRUE),
    media_consultas = survey_mean(num_consultas, na.rm = TRUE),
    n_bruto = unweighted(n())
  )
print(descritiva_raca)


### 7. MODELO 1 - só depressão
modelo1_svy <- svyglm(num_consultas ~ depressao, design = pns_desenho, family = gaussian())
summary(modelo1_svy)

# verificação (tem que bater com a tabela 2)
svyby(~num_consultas, ~depressao, pns_desenho, svymean, na.rm = TRUE)


### 8. FUNÇÃO AUXILIAR: SQT, SQE, SQR e R^2 (ponderados)
r2_pond <- function(modelo, design) {
  y_obs <- design$variables$num_consultas
  y_chapeu <- fitted(modelo)
  residuos <- resid(modelo)
  pesos <- weights(design)
  y_barra <- weighted.mean(y_obs, pesos, na.rm = TRUE)
  
  SQT <- sum(pesos * (y_obs - y_barra)^2, na.rm = TRUE)
  SQE <- sum(pesos * (y_chapeu - y_barra)^2, na.rm = TRUE)
  SQR <- sum(pesos * residuos^2, na.rm = TRUE)
  R2 <- SQE / SQT
  
  cat("SQT =", round(SQT, 2), "\n")
  cat("SQE =", round(SQE, 2), "\n")
  cat("SQR =", round(SQR, 2), "\n")
  cat("R^2  =", round(R2,  4), "\n")
  cat("Verificação (SQE + SQR ~= SQT):", round(SQE + SQR, 2), "\n")
  
  invisible(R2)
}

cat("R^2 - modelo 1:")
r2_m1 <- r2_pond(modelo1_svy, pns_desenho)


### 9. MODELO 2: + demográficos (gênero e idade)
modelo2_svy <- svyglm(num_consultas ~ depressao + feminino + idade,
  design = pns_desenho,
  family = gaussian())
summary(modelo2_svy)

cat("R^2 - modelo 2:")
r2_m2 <- r2_pond(modelo2_svy, pns_desenho)


### 10. MODELO 3: + instrução
modelo3_svy <- svyglm(num_consultas ~ depressao + feminino + idade + instrucao,
  design = pns_desenho,
  family = gaussian()
)
summary(modelo3_svy)

cat("R^2 - modelo 3:")
r2_m3 <- r2_pond(modelo3_svy, pns_desenho)


### 11. MODELO 4: + raça/cor
modelo4_svy <- svyglm(num_consultas ~ depressao + feminino + idade + instrucao + raca_cor,
  design = pns_desenho,
  family = gaussian()
)
summary(modelo4_svy)

cat("R^2 - modelo 4:")
r2_m4 <- r2_pond(modelo4_svy, pns_desenho)


### 12. MODELO 5: completo (+ log da renda per capita)
modelo5_svy <- svyglm(num_consultas ~ depressao + feminino + idade + instrucao + raca_cor + log_renda,
  design = pns_desenho,
  family = gaussian()
)
summary(modelo5_svy)

cat("R^2 - modelo 5:")
r2_m5 <- r2_pond(modelo5_svy, pns_desenho)


### 13. TESTE F
regTermTest(modelo3_svy, ~instrucao)
regTermTest(modelo4_svy, ~raca_cor)
regTermTest(modelo5_svy, "log_renda")
regTermTest(modelo5_svy, ~ feminino + idade + instrucao + raca_cor + log_renda)


### 14. COMPARAÇÃO ENTRE MODELOS
cat("\nEvolução do coeficiente da depressão:\n")
beta_dep <- c(
  coef(modelo1_svy)["depressao"],
  coef(modelo2_svy)["depressao"],
  coef(modelo3_svy)["depressao"],
  coef(modelo4_svy)["depressao"],
  coef(modelo5_svy)["depressao"]
)

cat("\nEfeito estimado da depressão (número de consultas adicionais):\n")
cat("M1 (só depressão):", round(beta_dep[1], 2), "consultas\n")
cat("M2 (+ demográficos):", round(beta_dep[2], 2), "consultas\n")
cat("M3 (+ instrução):", round(beta_dep[3], 2), "consultas\n")
cat("M4 (+ raça/cor):", round(beta_dep[4], 2), "consultas\n")
cat("M5 (completo com renda):", round(beta_dep[5], 2), "consultas\n")
cat("Variação M1 a M5:", round(beta_dep[5] - beta_dep[1], 2), "consultas\n")

stargazer( # tabela comparativa final (verificação final de valores, tamanhos de amostra etc etc)
  modelo1_svy, modelo2_svy, modelo3_svy, modelo4_svy, modelo5_svy,
  type = "text",
  title = "Determinantes do número de consultas médicas anuais - PNS 2019",
  dep.var.labels = "Número de consultas médicas (últimos 12 meses)",
  column.labels = c("M1", "M2", "M3", "M4", "M5"),
  covariate.labels = c(
    "Diagnóstico de depressão (ref. = Não)",
    "Feminino (ref. = Masculino)",
    "Idade (anos)",
    "Fund. incompleto", "Fund. completo",
    "Médio incompleto", "Médio completo",
    "Superior incompleto", "Superior completo",
    "Preta", "Amarela", "Parda", "Indígena",
    "Log da renda domiciliar per capita"
  ),
  add.lines = list(c("R^2", round(r2_m1, 4), round(r2_m2, 4), round(r2_m3, 4), round(r2_m4, 4), round(r2_m5, 4))),
  keep.stat = c("n")
)