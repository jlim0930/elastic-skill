# Customer Data Redaction Requirements

- Redact customer-identifying information as much as possible.
- Do not reproduce raw hostnames, FQDNs, IP addresses, URLs, node names, allocator names, deployment names, cluster names, usernames, email addresses, certificate subjects, or other unique identifiers unless absolutely necessary for technical clarity.
- Prefer generalized placeholders such as:
  - `<cluster>`
  - `<node>`
  - `<allocator>`
  - `<host>`
  - `<container>`
  - `<deployment>`
  - `<hostname>`
  - `<ip>`
  - `<endpoint>`
  - `<service>`
- If quoting logs or errors, redact identifying values while preserving technical meaning.
- Summarize patterns rather than repeating customer-specific infrastructure details.
- Never expose credentials, tokens, API keys, certificates, private keys, or secret contents.
- If an identifier is necessary to distinguish objects, use stable placeholders such as `<allocator-a>`, `<allocator-b>`, `<node-1>`, `<node-2>`.
