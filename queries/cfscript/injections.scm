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


;; extends

;; Suntik HTML ke string yang mengandung tag HTML
((string
   (string_fragment) @injection.content)
  (#lua-match? @injection.content "<[/!]?%a")
  (#set! injection.language "html")
  (#set! injection.combined))
