;; extends

([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
] @injection.content
  (#match? @injection.content "\\v\\c<(select|insert\\_s+into|update|delete\\_s+from|create\\_s+table|alter\\_s+table)>")
  (#set! injection.language "sql"))
