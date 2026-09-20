; Indentation for CFML
; See https://tree-sitter.github.io/tree-sitter/syntax-highlighting#indentation

; HTML elements
(element
  (start_tag) @indent.begin)
(element
  (end_tag) @indent.end)
(script_element
  (start_tag) @indent.begin)
(script_element
  (end_tag) @indent.end)
(style_element
  (start_tag) @indent.begin)
(style_element
  (end_tag) @indent.end)

; CF tags with explicit start/end (cfloop, cfmail, etc.)
(cf_tag
  (cf_start_tag) @indent.begin)
(cf_tag
  (cf_end_tag) @indent.end)

; CF component tags
(cf_component_open_tag) @indent
(cf_component_close_tag) @dedent

; CF block tags (cfif, cffunction, cfoutput, cfscript, cfquery, cfsavecontent)
(cf_if_tag) @indent
(cf_function_tag) @indent
(cf_output_tag) @indent
(cf_script_tag) @indent
(cf_query_tag) @indent
(cf_savecontent_tag) @indent

; Script-level nodes (expressions inside cfset, cfif, cfreturn, cfscript, etc.)
(statement_block "{" @indent.begin)
(statement_block "}" @indent.end)
(switch_body "{" @indent.begin)
(switch_body "}" @indent.end)
(object "{" @indent.begin)
(object "}" @indent.end)
(object_pattern "{" @indent.begin)
(object_pattern "}" @indent.end)
(named_imports "{" @indent.begin)
(named_imports "}" @indent.end)
(formal_parameters "(" @indent.begin)
(formal_parameters ")" @indent.end)
(arguments "(" @indent.begin)
(arguments ")" @indent.end)
(parenthesized_expression "(" @indent.begin)
(parenthesized_expression ")" @indent.end)
(array "[" @indent.begin)
(array "]" @indent.end)
(array_pattern "[" @indent.begin)
(array_pattern "]" @indent.end)

