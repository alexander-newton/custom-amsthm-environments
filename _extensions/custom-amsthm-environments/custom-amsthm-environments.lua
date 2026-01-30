-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- VERSION: Safe Lua Tables (Prevents Quarto 'jog.lua' crashes)

function Pandoc(doc)
  -- 1. READ CONFIGURATION
  local envs = {}
  local raw_config = doc.meta['custom-amsthm'] or doc.meta['amsthm-environments']
  
  if raw_config then
    for _, item in ipairs(raw_config) do
      local entry = {}
      if type(item) == 'table' then
        entry.id = pandoc.utils.stringify(item.key or item.id)
        entry.title = pandoc.utils.stringify(item.name or item.title)
      else
        entry.id = pandoc.utils.stringify(item)
        entry.title = entry.id:gsub("^%l", string.upper)
      end
      table.insert(envs, entry)
    end
  end

  -- Helper: Detect environment
  local function detect_environment(div)
    for _, env in ipairs(envs) do
      local prefix = env.id .. "-"
      if div.identifier:find("^" .. prefix) then return env end
      if div.classes:includes(env.id) then return env end
    end
    return nil
  end

  local id_map = {} 
  
  -- PASS 1: PROCESS BLOCKS
  doc.blocks = doc.blocks:walk {
    Div = function(div)
      local env = detect_environment(div)
      
      if env then
        -- A. SETUP TITLE & CONTENT
        -- We use a plain Lua table for safety
        local clean_content = {}
        local final_title = div.attributes["name"] or env.title
        local start_index = 1
        
        -- Header Extraction Logic
        -- Check if the first block is a Header (and user hasn't forced a name)
        if #div.content > 0 and div.content[1].t == "Header" then
           if not div.attributes["name"] then
             final_title = pandoc.utils.stringify(div.content[1].content)
           end
           start_index = 2 -- Skip the header block in the output
        end

        -- Copy remaining blocks into our clean Lua table
        for i = start_index, #div.content do
           table.insert(clean_content, div.content[i])
        end

        -- B. UNIFIED ID LOGIC
        local original_id = div.identifier
        local new_id = original_id
        
        if not original_id:match("^thm%-") then
          new_id = "thm-" .. original_id
          if original_id == "" then 
             new_id = "thm-" .. env.id .. "-" .. tostring(math.random(10000))
          end
          if original_id ~= "" then
             id_map[original_id] = new_id 
          end
        end
        div.identifier = new_id

        -- C. HTML OUTPUT
        if quarto.doc.is_format("html") then
           -- For HTML, we modify the Div in-place and return it
           div.classes:insert("theorem")
           div.classes:insert(env.id)
           div.attributes["type"] = "theorem"
           div.attributes["name"] = final_title
           
           -- Update content (pandoc converts Lua table -> List automatically here)
           div.content = clean_content 
           return div
        end

        -- D. LATEX OUTPUT
        if quarto.doc.is_format("latex") then
          local label_cmd = ""
          if div.identifier ~= "" then
            label_cmd = "\\label{" .. div.identifier .. "}"
          end
          
          local begin_cmd = "\\begin{" .. env.id .. "}"
          if final_title then
            begin_cmd = begin_cmd .. "[" .. final_title .. "]"
          end
          
          local raw_begin = pandoc.RawBlock("latex", begin_cmd .. label_cmd)
          local raw_end = pandoc.RawBlock("latex", "\\end{" .. env.id .. "}")
          
          -- Construct result as a simple Lua table of blocks
          -- This is the standard return type for splicing in Pandoc
          local result_blocks = { raw_begin }
          for _, block in ipairs(clean_content) do
            table.insert(result_blocks, block)
          end
          table.insert(result_blocks, raw_end)
          
          return result_blocks
        end
        
        return div
      end
    end
  }

  -- PASS 2: FIX REFERENCES
  doc = doc:walk {
    Cite = function(cite)
      for _, citation in ipairs(cite.citations) do
        if id_map[citation.id] then
          citation.id = id_map[citation.id]
        end
      end
      return cite
    end,
    Link = function(link)
      local clean_hash = link.target:match("^#(.*)")
      if clean_hash and id_map[clean_hash] then
        link.target = "#" .. id_map[clean_hash]
      end
      return link
    end
  }

  -- PASS 3: LATEX HEADER
  if quarto.doc.is_format("latex") and #envs > 0 then
    local header = ""
    local master = "theorem"
    
    local user_has_theorem = false
    for _, e in ipairs(envs) do if e.id == "theorem" then user_has_theorem = true end end
    if not user_has_theorem then master = envs[1].id end
    
    for _, e in ipairs(envs) do
      if e.id == master then
         header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    for _, e in ipairs(envs) do
      if e.id ~= master then
         if user_has_theorem or (e.id ~= envs[1].id) then
            header = header .. "\\newtheorem{" .. e.id .. "}[" .. master .. "]{" .. e.title .. "}\n"
         end
      end
    end
    
    quarto.doc.include_text("in-header", header)
  end

  return doc
end
