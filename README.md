# O impacto da depressão na demanda por serviços de saúde

Análise econométrica em R dos determinantes do número de consultas médicas no Brasil, com microdados da Pesquisa Nacional de Saúde (PNS) 2019, do IBGE.

Trabalho final da disciplina de Econometria (2026.1), Universidade Federal de São Paulo (Unifesp). O artigo não foi publicado.

## Pergunta de pesquisa

Pessoas com diagnóstico de depressão fazem mais consultas médicas por ano do que pessoas sem o diagnóstico? E essa diferença se mantém depois de controlar por gênero, idade, escolaridade, raça/cor e renda domiciliar per capita?

## Dados

- **Fonte:** [PNS 2019](https://www.ibge.gov.br/estatisticas/sociais/saude/9160-pesquisa-nacional-de-saude.html) (IBGE, em parceria com o Ministério da Saúde). Dados públicos, corte transversal, questionário do morador selecionado.
- **Obtenção:** o script baixa os microdados direto do IBGE com o pacote [`PNSIBGE`](https://cran.r-project.org/package=PNSIBGE).
- **Amostra final:** 88.500 adultos (18 anos ou mais) com informação completa em todas as variáveis utilizadas.

| Variável | Código na PNS | Tratamento |
|---|---|---|
| Nº de consultas médicas nos últimos 12 meses (**Y**) | J012 | "Ignorado" (999) tratado como ausente; quem não consultou foi codificado como 0 |
| Diagnóstico de depressão (**X principal**) | Q092 | dummy: Sim = 1, Não = 0 |
| Sexo | C006 | dummy feminino (ref. = homem) |
| Idade | C008 | contínua, em anos |
| Nível de instrução | VDD004A | dummies (ref. = sem instrução) |
| Raça/cor | C009 | dummies (ref. = branca); "Ignorado" excluído |
| Renda domiciliar per capita | VDF003 | log(renda + 1) |

## Metodologia

- Regressão linear múltipla por Mínimos Quadrados Ordinários, ponderada pelo plano amostral (`svyglm` do pacote `survey`).
- **Plano amostral complexo da PNS** declarado com `svydesign`: unidade primária de amostragem (`UPA_PNS`), estratos (`V0024`) e peso do morador selecionado (`V00291`). Os erros padrão consideram esse desenho.
- Cinco especificações, adicionando controles de forma progressiva para verificar a estabilidade do coeficiente de depressão:
  1. apenas depressão
  2. + gênero e idade
  3. + nível de instrução
  4. + raça/cor
  5. + log da renda per capita (modelo completo)
- R² ponderado calculado por função própria (SQT, SQE e SQR).
- Testes F conjuntos (`regTermTest`) para os blocos de instrução, raça/cor, renda e todos os controles.
- As estatísticas descritivas usam pesos amostrais, então as proporções representam a população adulta brasileira, e não a amostra bruta.

## Principais resultados

| Modelo | Coeficiente de depressão (consultas/ano) | R² |
|---|---|---|
| 1. Apenas depressão | 2,44 | 0,0205 |
| 2. + gênero e idade | 2,06 | 0,0401 |
| 3. + instrução | 2,05 | 0,0410 |
| 4. + raça/cor | 2,06 | 0,0419 |
| 5. Completo (+ renda) | 2,05 | 0,0421 |

Todos os coeficientes de depressão são significativos a 1%.

- Na estatística descritiva, quem tem diagnóstico de depressão faz em média 5,3 consultas por ano, contra 2,86 entre quem não tem.
- No modelo completo, mantidas as demais variáveis constantes, o diagnóstico de depressão está associado a cerca de 2,05 consultas a mais por ano.
- O coeficiente é estável ao longo das cinco especificações.
- Mulheres fazem cerca de 1 consulta a mais por ano que homens, e a renda tem associação positiva e significativa com o número de consultas.

Os resultados indicam **associação**, não causalidade.

## Limitações

- Dados autodeclarados e de corte transversal.
- A variável dependente é uma contagem com forte dispersão, analisada aqui com modelo linear.
- As categorias de raça/cor "Amarela" e "Indígena" têm poucas observações, então as estimativas para esses grupos são pouco precisas.

## Estrutura do repositório

```
.
├── README.md
├── artigo/
│   └── artigo_depressao_consultas_pns2019.pdf   artigo completo
├── codigo/
│   └── analise_pns2019.R                        script completo da análise
└── .gitignore
```

## Como reproduzir

1. Instale o [R](https://cran.r-project.org/) e, de preferência, o RStudio.
2. Clone este repositório e abra `codigo/analise_pns2019.R`.
3. Rode a seção 1 do script uma vez para instalar os pacotes: `tidyverse`, `PNSIBGE`, `survey`, `srvyr` e `stargazer`.
4. Rode o restante do script em ordem. Na primeira execução, o `get_pns()` baixa os microdados do IBGE, o que pode demorar.
5. Os resultados (tabelas descritivas, modelos, R² e testes F) são impressos no console.

## Autoria

Letícia Fonseca Pereira — [LinkedIn](https://linkedin.com/in/leticiafpereira/)