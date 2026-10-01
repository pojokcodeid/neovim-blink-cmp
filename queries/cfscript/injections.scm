;; extends

((query_expression
  (query_text) @injection.content)
 (#set! injection.language "sql"))

; String biasa yang berisi SQL (mis. strquery: "SELECT ...")
((string
   (string_fragment) @injection.content) @_str
  (#match? @_str "\\c(select|insert|update|delete|join)\\s")
  (#set! injection.language "sql")
  (#set! injection.combined))

; Argumen SQL di queryExecute("...")
((query_text) @injection.content
  (#set! injection.language "sql")
  (#set! injection.combined))

;; String biasa yang isinya SQL (mis. qTextQuery = "UPDATE ... SET ...")
((string
   (string_fragment) @injection.content) @_str
 (#match? @_str "\\v\\c^.\\_s*(select\\_s\\_.*\\_sfrom\\_s|insert\\_s+into\\_s|update\\_s+\\S+\\_s+set\\_s|delete\\_s+from\\_s)")
 (#set! injection.language "sql")
 (#set! injection.combined))


;; extends

;; Suntik HTML ke string yang mengandung tag HTML
((string
   (string_fragment) @injection.content)
  (#lua-match? @injection.content "<[/!]?%a")
  (#set! injection.language "html")
  (#set! injection.combined))
