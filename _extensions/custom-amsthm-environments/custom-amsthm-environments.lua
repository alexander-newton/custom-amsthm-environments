-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- STRICT VERSION: Uses pandoc.List() everywhere to prevent Quarto crashes.

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
        -- A. PREPARE CONTENT & TITLE (Using Strict pandoc.List)
        local new_content = pandoc.List()
        local final_title = div.attributes["name"] or env.title
        
        local start_index = 1
        
        -- Check for Header Extraction
        if #div.content > 0 and div.content[1].t == "Header" then
           -- If user didn't manually set name="", use the header text
           if not div.attributes["name"] then
              final_title = pandoc.utils.stringify(div.content[1].content)
           end
           -- Skip the header in the output
           start_index = 2
        end

        -- Copy remaining blocks safely into the pandoc.List
        for i = start_index, #div.content do
           new_content:insert(div.content[i])
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
           div.classes:insert("theorem")
           div.classes:insert(env.id)
           div.attributes["type"] = "theorem"
           div.attributes["name"] = final_title
           
           -- Assigning a pandoc.List to .content is safe
           div.content = new_content 
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
          
          -- Construct the strict return List
          local result_blocks = pandoc.List()
          result_blocks:insert(raw_begin)
          result_blocks:extend(new_content)
          result_blocks:insert(raw_end)
          
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
