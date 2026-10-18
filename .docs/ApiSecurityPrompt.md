# Requisitos Base de Qualquer API (Segurança e Fundamentos)

> **Como usar este arquivo:** forneça-o como contexto ao LLM antes de pedir a geração da API. Tudo aqui é **obrigatório**, independente do domínio ou propósito da API. Se algum item não puder ser cumprido, o LLM deve avisar explicitamente e explicar o motivo, nunca omitir em silêncio.

## Instruções para o LLM

- Trate cada item marcado como **[OBRIGATÓRIO]** como requisito inegociável.
- Itens **[RECOMENDADO]** devem ser implementados a menos que o escopo do projeto justifique não fazê-lo (e isso deve ser dito).
- Não invente criptografia, não implemente hash de senha ou JWT "na mão": use bibliotecas consolidadas e mantidas.
- Nunca coloque segredos, chaves ou senhas no código ou em exemplos reais. Use variáveis de ambiente.
- Ao final, devolva uma lista dizendo quais itens deste arquivo foram implementados, quais ficaram de fora e por quê.

---

## 1. Autenticação

- **[OBRIGATÓRIO]** Toda rota é autenticada por padrão (deny by default). Rotas públicas são exceções explícitas e listadas (ex.: login, registro, health check).
- **[OBRIGATÓRIO]** Senhas armazenadas apenas com hash lento e com salt: **Argon2id** (preferido), bcrypt ou scrypt. Nunca MD5, SHA-1, SHA-256 puro ou texto plano.
- **[OBRIGATÓRIO]** Tokens de acesso com **expiração curta** (ex.: 5 a 15 minutos). Se usar JWT: validar assinatura, `exp`, `iss` e `aud`; fixar o algoritmo esperado (rejeitar `alg: none`); chave secreta forte e fora do código.
- **[OBRIGATÓRIO]** Refresh tokens (se existirem) com rotação, armazenados com hash no servidor, e revogáveis (logout invalida).
- **[OBRIGATÓRIO]** Mensagens de erro de login genéricas ("credenciais inválidas"), sem revelar se o usuário existe.
- **[OBRIGATÓRIO]** Proteção contra força bruta no login (rate limit por IP e por conta, bloqueio temporário ou atraso progressivo).
- **[RECOMENDADO]** Política mínima de senha (tamanho mínimo de 12 caracteres, sem regras absurdas de composição; checar contra senhas vazadas se possível).
- **[RECOMENDADO]** Suporte a MFA para contas sensíveis.
- **[RECOMENDADO]** Para comunicação entre serviços: API keys com escopo limitado, ou mTLS / OAuth2 client credentials.
- **[OBRIGATÓRIO]** Chaves de API (se existirem) armazenadas com hash, exibidas só uma vez na criação, rotacionáveis e revogáveis.

## 2. Autorização

- **[OBRIGATÓRIO]** Verificar permissão **em toda requisição, no servidor**, nunca confiar no que o cliente envia (papel, id de usuário, flags).
- **[OBRIGATÓRIO]** Proteção contra **BOLA/IDOR**: ao acessar um recurso por id, validar que ele pertence ao usuário autenticado (ou que ele tem permissão). Ex.: `GET /pedidos/123` deve checar o dono do pedido 123.
- **[OBRIGATÓRIO]** Proteção contra **escalada de função**: rotas administrativas exigem papel adequado, verificado no backend.
- **[OBRIGATÓRIO]** Princípio do menor privilégio: cada papel/escopo tem só o necessário.
- **[OBRIGATÓRIO]** Proteção contra **mass assignment**: nunca vincular o corpo da requisição direto ao modelo do banco. Usar DTOs/structs de entrada com campos explicitamente permitidos (o cliente não pode setar `role`, `is_admin`, `id`, `owner_id`, etc.).
- **[OBRIGATÓRIO]** O id do usuário vem do token autenticado, não de parâmetro enviado pelo cliente.

## 3. Validação de Entrada

- **[OBRIGATÓRIO]** Validar **tudo** que vem de fora: body, query string, path params, headers, cookies, uploads.
- **[OBRIGATÓRIO]** Validação por **allowlist** (definir o que é aceito), não por blocklist.
- **[OBRIGATÓRIO]** Validar tipo, tamanho, formato, faixa de valores e campos obrigatórios. Rejeitar campos desconhecidos quando possível.
- **[OBRIGATÓRIO]** Limitar o **tamanho máximo do body** e de strings, arrays e campos aninhados (evitar payloads gigantes e JSON profundamente aninhado).
- **[OBRIGATÓRIO]** Validar `Content-Type` esperado; responder `415` se for outro.
- **[OBRIGATÓRIO]** Paginação com limite máximo imposto no servidor (ex.: `limit` máximo de 100), mesmo que o cliente peça mais.
- **[OBRIGATÓRIO]** Uploads (se existirem): validar tipo real pelo conteúdo (não só extensão ou header), limitar tamanho, renomear o arquivo, armazenar fora do diretório servido, nunca executar.
- **[OBRIGATÓRIO]** Tratar IDs como opacos: preferir UUID/ULID a inteiros sequenciais em recursos expostos, para dificultar enumeração (isso **não substitui** checagem de autorização).

## 4. Proteção Contra Injeção e Ataques Comuns

- **[OBRIGATÓRIO]** **SQL injection:** sempre queries parametrizadas / prepared statements ou ORM usado corretamente. Nunca concatenar input em SQL.
- **[OBRIGATÓRIO]** **NoSQL / command / LDAP injection:** nunca montar queries, comandos de shell ou filtros concatenando input. Evitar executar comandos do sistema com dados do usuário.
- **[OBRIGATÓRIO]** **SSRF:** se a API faz requisições a URLs fornecidas pelo usuário, usar allowlist de domínios, bloquear IPs internos/loopback/metadados de nuvem (`169.254.169.254`, `127.0.0.0/8`, `10.0.0.0/8`, etc.), limitar redirects e definir timeout.
- **[OBRIGATÓRIO]** **Path traversal:** nunca montar caminhos de arquivo com input cru; normalizar e confinar a um diretório base.
- **[OBRIGATÓRIO]** **XSS:** se a API retorna conteúdo que será renderizado em HTML, escapar/sanitizar; sempre responder com `Content-Type` correto e `X-Content-Type-Options: nosniff`.
- **[RECOMENDADO]** **CSRF:** se usar cookies para autenticação, adotar `SameSite=Lax/Strict`, token anti-CSRF ou checagem de `Origin`. APIs que usam apenas `Authorization: Bearer` em header têm risco bem menor.
- **[OBRIGATÓRIO]** Desserialização segura: não desserializar objetos arbitrários vindos do cliente.
- **[OBRIGATÓRIO]** Proteção contra **ReDoS**: evitar regex complexas aplicadas a input não limitado.

## 5. Rate Limiting e Proteção Contra Abuso (DoS)

- **[OBRIGATÓRIO]** Rate limiting global e por cliente (IP, usuário ou API key), com limites mais rígidos em rotas sensíveis (login, recuperação de senha, envio de e-mail/SMS, criação de conta).
- **[OBRIGATÓRIO]** Responder `429 Too Many Requests` com header `Retry-After`.
- **[OBRIGATÓRIO]** **Timeouts** em tudo: leitura/escrita do servidor HTTP, conexões ao banco, chamadas a serviços externos.
- **[OBRIGATÓRIO]** Limite de conexões simultâneas e de tamanho de requisição.
- **[OBRIGATÓRIO]** Limitar custo de operações caras: paginação obrigatória, limite de profundidade/complexidade (ex.: GraphQL), limite de itens em operações em lote (bulk).
- **[RECOMENDADO]** Cotas por cliente para operações que consomem recursos pagos ou externos.

## 6. Transporte e Headers de Segurança

- **[OBRIGATÓRIO]** **HTTPS/TLS** em produção (TLS 1.2+; preferir 1.3). HTTP só redireciona ou é bloqueado.
- **[OBRIGATÓRIO]** Header `Strict-Transport-Security` (HSTS) em produção.
- **[OBRIGATÓRIO]** Headers: `X-Content-Type-Options: nosniff`, `Cache-Control: no-store` em respostas com dados sensíveis, `Content-Security-Policy` restritivo se servir HTML, `X-Frame-Options: DENY` ou `frame-ancestors` equivalente.
- **[OBRIGATÓRIO]** Não expor headers que revelam tecnologia/versão (`Server`, `X-Powered-By`).
- **[OBRIGATÓRIO]** **CORS** restritivo: allowlist explícita de origens. **Nunca** `Access-Control-Allow-Origin: *` junto com credenciais. Nunca refletir o header `Origin` cegamente.
- **[OBRIGATÓRIO]** Desabilitar métodos HTTP não usados (responder `405`); `TRACE` sempre desabilitado.

## 7. Segredos e Configuração

- **[OBRIGATÓRIO]** Nenhum segredo no código ou no repositório (chaves, senhas, tokens, strings de conexão). Usar variáveis de ambiente ou gerenciador de segredos.
- **[OBRIGATÓRIO]** Arquivo `.env` no `.gitignore`; fornecer `.env.example` sem valores reais.
- **[OBRIGATÓRIO]** Configuração validada na inicialização: a aplicação **falha rápido** se faltar variável obrigatória ou se o segredo for fraco/padrão.
- **[OBRIGATÓRIO]** Separar configurações por ambiente (dev, teste, produção). Modo debug e endpoints de depuração **desligados** em produção.
- **[OBRIGATÓRIO]** Sem credenciais padrão (admin/admin etc.).
- **[RECOMENDADO]** Rotação de segredos prevista no design.

## 8. Tratamento de Erros

- **[OBRIGATÓRIO]** Erros retornados ao cliente são genéricos e padronizados. **Nunca** expor stack trace, queries SQL, caminhos de arquivo, versões ou mensagens internas.
- **[OBRIGATÓRIO]** Detalhes técnicos vão para o log do servidor, com um **ID de correlação** devolvido ao cliente para suporte.
- **[OBRIGATÓRIO]** Formato de erro consistente (ex.: RFC 7807 `application/problem+json` ou um padrão único próprio).
- **[OBRIGATÓRIO]** Uso correto de status HTTP: `400` entrada inválida, `401` não autenticado, `403` sem permissão, `404` não encontrado, `409` conflito, `413` payload grande, `415` tipo de mídia, `422` erro de validação semântica, `429` rate limit, `500` erro interno.
- **[OBRIGATÓRIO]** Recuperação de panics/exceções não tratadas (middleware global) sem derrubar o processo nem vazar detalhes.
- **[RECOMENDADO]** Para recursos de outros usuários, preferir `404` a `403` quando revelar a existência do recurso for um problema.

## 9. Logs, Auditoria e Observabilidade

- **[OBRIGATÓRIO]** Logs **estruturados** (JSON) com timestamp, nível, ID de requisição/correlação, método, rota, status e latência.
- **[OBRIGATÓRIO]** **Nunca logar** senhas, tokens, chaves de API, números de cartão, dados pessoais sensíveis ou corpos completos de requisição com esses dados. Mascarar o que for necessário.
- **[OBRIGATÓRIO]** Proteção contra **log injection**: sanitizar quebras de linha e caracteres de controle em dados vindos do usuário.
- **[OBRIGATÓRIO]** Registrar eventos de segurança: logins (sucesso e falha), falhas de autorização, mudanças de permissão, alterações de senha, acessos negados, rate limit atingido.
- **[RECOMENDADO]** Métricas (latência, taxa de erro, throughput) e tracing distribuído (ex.: OpenTelemetry).
- **[RECOMENDADO]** Trilha de auditoria imutável para ações críticas (quem fez o quê, quando).

## 10. Banco de Dados e Dados Sensíveis

- **[OBRIGATÓRIO]** Usuário do banco da aplicação com **privilégios mínimos** (sem permissão de DDL/superuser em runtime).
- **[OBRIGATÓRIO]** Conexão ao banco com TLS quando não estiver na mesma rede confiável.
- **[OBRIGATÓRIO]** Migrações versionadas e reproduzíveis; nunca alterar schema manualmente em produção.
- **[OBRIGATÓRIO]** Retornar apenas os campos necessários: nunca devolver `password_hash`, tokens internos ou campos de auditoria. Usar DTOs de saída.
- **[OBRIGATÓRIO]** Transações para operações que alteram múltiplas tabelas e exigem consistência.
- **[OBRIGATÓRIO]** Pool de conexões com limites configurados.
- **[RECOMENDADO]** Criptografia em repouso para dados sensíveis (disco/coluna) e backups cifrados e testados.
- **[RECOMENDADO]** Soft delete ou política de retenção definida para dados importantes.

## 11. Privacidade e Dados Pessoais (LGPD)

- **[OBRIGATÓRIO]** Coletar somente os dados pessoais realmente necessários (minimização).
- **[OBRIGATÓRIO]** Prever como atender direitos do titular: acesso, correção, exclusão/anonimização e exportação dos dados.
- **[OBRIGATÓRIO]** Não incluir dados pessoais em URLs (query string/path), pois acabam em logs e caches.
- **[RECOMENDADO]** Definir política de retenção e descarte de dados.

## 12. Dependências e Cadeia de Suprimentos

- **[OBRIGATÓRIO]** Usar bibliotecas populares, mantidas e com versões atualizadas. Fixar versões (lockfile / `go.sum` / `package-lock.json`).
- **[OBRIGATÓRIO]** Rodar verificação de vulnerabilidades nas dependências (ex.: `govulncheck`, `npm audit`, `pip-audit`, Dependabot/Renovate) e prever isso no CI.
- **[OBRIGATÓRIO]** Evitar dependências desnecessárias.
- **[RECOMENDADO]** Imagens Docker mínimas, de fontes oficiais, rodando como **usuário não-root**, com filesystem somente leitura quando possível, e escaneadas (ex.: Trivy).

## 13. Design e Contrato da API

- **[OBRIGATÓRIO]** Versionamento (ex.: `/v1/...`).
- **[OBRIGATÓRIO]** Semântica HTTP correta: `GET` sem efeitos colaterais, `POST` cria, `PUT/PATCH` atualiza, `DELETE` remove. Operações idempotentes onde fizer sentido.
- **[OBRIGATÓRIO]** Formato de resposta consistente (envelope, nomes de campos, formato de datas em ISO 8601 UTC).
- **[OBRIGATÓRIO]** Paginação, filtros e ordenação padronizados em listagens.
- **[OBRIGATÓRIO]** Documentação **OpenAPI/Swagger** atualizada e gerada/validada junto do código. Em produção, a documentação interativa não deve expor rotas internas sem controle de acesso.
- **[RECOMENDADO]** Suporte a `Idempotency-Key` em operações críticas de criação/pagamento, para tolerar retentativas.
- **[RECOMENDADO]** Controle de concorrência otimista (`ETag`/`If-Match` ou campo `version`) em atualizações.
- **[RECOMENDADO]** Política clara de depreciação de versões antigas.
- **[OBRIGATÓRIO]** Inventário de endpoints: nenhuma rota esquecida, de teste ou de depuração exposta em produção.

## 14. Operação e Resiliência

- **[OBRIGATÓRIO]** Endpoints de **health check** (`/health/live` e `/health/ready`) sem expor informações sensíveis.
- **[OBRIGATÓRIO]** **Graceful shutdown**: ao receber SIGTERM, parar de aceitar requisições novas e terminar as em andamento dentro de um prazo.
- **[OBRIGATÓRIO]** Retentativas com backoff exponencial e jitter ao chamar serviços externos; circuit breaker quando fizer sentido.
- **[OBRIGATÓRIO]** Contexto de cancelamento/timeout propagado por toda a cadeia (requisição, banco, chamadas externas).
- **[RECOMENDADO]** Estratégia de backup e restauração documentada e testada.
- **[RECOMENDADO]** Feature flags / configuração para desligar funcionalidades problemáticas sem novo deploy.

## 15. Testes e Qualidade

- **[OBRIGATÓRIO]** Testes unitários para regras de negócio e validação.
- **[OBRIGATÓRIO]** Testes de integração para as rotas (incluindo caminhos de erro).
- **[OBRIGATÓRIO]** **Testes de segurança/autorização**: acesso sem token, token expirado, token de outro usuário (BOLA), papel insuficiente, payload malformado, campos extras (mass assignment), payload gigante.
- **[OBRIGATÓRIO]** Linter e análise estática no CI (ex.: `golangci-lint` com `gosec`, Semgrep, CodeQL).
- **[RECOMENDADO]** Fuzzing em parsers e validações críticas.
- **[RECOMENDADO]** Pipeline de CI/CD que bloqueia merge quando testes, lint ou verificação de vulnerabilidades falham.

## 16. Estrutura de Código Esperada

- **[RECOMENDADO]** Separar camadas: transporte (handlers/rotas), regras de negócio (serviços) e acesso a dados (repositórios), com injeção de dependências, facilitando testes.
- **[RECOMENDADO]** Middlewares centralizados para: autenticação, autorização, rate limit, logging, recuperação de panics, CORS, headers de segurança, ID de requisição.
- **[RECOMENDADO]** Configuração centralizada e tipada; sem variáveis globais mutáveis.
- **[RECOMENDADO]** README com como rodar, variáveis de ambiente necessárias, como testar e como fazer deploy.

---

## Mapeamento Rápido com OWASP API Security Top 10 (2023)

| Risco OWASP | Onde está coberto neste arquivo |
|---|---|
| API1 Broken Object Level Authorization | Seção 2 |
| API2 Broken Authentication | Seção 1 |
| API3 Broken Object Property Level Authorization | Seções 2 e 10 (mass assignment, DTOs de saída) |
| API4 Unrestricted Resource Consumption | Seções 3 e 5 |
| API5 Broken Function Level Authorization | Seção 2 |
| API6 Unrestricted Access to Sensitive Business Flows | Seção 5 (rate limit em fluxos sensíveis) |
| API7 Server Side Request Forgery | Seção 4 |
| API8 Security Misconfiguration | Seções 6, 7 e 8 |
| API9 Improper Inventory Management | Seção 13 |
| API10 Unsafe Consumption of APIs | Seções 3, 4 e 14 (validar também o que vem de APIs de terceiros) |

---

## Checklist Final (o LLM deve preencher ao entregar a API)

- [ ] Todas as rotas exigem autenticação, exceto as públicas listadas
- [ ] Autorização por recurso verificada no servidor (BOLA/IDOR coberto)
- [ ] Senhas com Argon2id/bcrypt; tokens com expiração curta
- [ ] Entrada validada com allowlist, limites de tamanho e paginação máxima
- [ ] Queries parametrizadas; sem concatenação de input
- [ ] DTOs de entrada e saída (sem mass assignment, sem vazamento de campos)
- [ ] Rate limiting global e reforçado em rotas sensíveis
- [ ] Timeouts configurados (servidor, banco, chamadas externas)
- [ ] HTTPS, HSTS e headers de segurança configurados
- [ ] CORS com allowlist explícita
- [ ] Segredos fora do código; app falha rápido sem configuração válida
- [ ] Erros genéricos ao cliente, detalhes só no log com ID de correlação
- [ ] Logs estruturados, sem dados sensíveis, com eventos de segurança registrados
- [ ] Dependências verificadas contra vulnerabilidades
- [ ] Health checks e graceful shutdown implementados
- [ ] OpenAPI documentado; versionamento aplicado
- [ ] Testes de autorização e de segurança escritos
- [ ] Itens não implementados listados com justificativa
