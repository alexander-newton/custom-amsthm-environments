-- Custom AMSTHM Environments: Continuous Numbering (Robust Version)
-- Works with your YAML config (custom-amsthm) and ID-based prefixes (#axm-...)

function Pandoc(doc)
  -- 1. READ CONFIGURATION
  -- Look for 'custom-amsthm' (your config) OR 'amsthm-environments' (standard)
  local envs = {}
  local raw_config = doc.meta['custom-amsthm'] or doc.meta['amsthm-environments']
  
  if raw_config then
    for _, item in ipairs(raw_config) do
      -- Normalize your 'key/name' format to our internal 'id/title' format
      local entry = {}
      
      if type(item) == 'table' then
        -- Handle: - key: axm, name: Axiom
        entry.id = pandoc.utils.stringify(item.key or item.id)
        entry.title = pandoc.utils.stringify(item.name or item.title)
      else
        -- Handle: - axiom
        entry.id = pandoc.utils.stringify(item)
        entry.title = entry.id:gsub("^%l", string.upper)
      end
      
      table.insert(envs, entry)
    end
  end

  -- Helper: Match a Div to an environment by Class (.axm) OR ID prefix (#axm-...)
  local function detect_environment(div)
    for _, env in ipairs(envs) do
      local prefix = env.id .. "-"
      
      -- Check 1: Does the ID start with "axm-"? (e.g. #axm-savage)
      if div.identifier:find("^" .. prefix) then
        return env
      end
      
      -- Check 2: Does it have the class? (e.g. .axm)
      if div.classes:includes(env.id) then
        return env
      end
    end
    return nil
  end

  local id_map = {} -- Maps "axm-savage" -> "thm-axm-savage"
  
  -- PASS 1: PROCESS BLOCKS
  doc.blocks = doc.blocks:walk {
    Div = function(div)
      local env = detect_environment(div)
      
      if env then
        local original_id = div.identifier
        local env_id = env.id      -- e.g., "axm"
        local env_title = env.title -- e.g., "Axiom"
        
        -- A. UNIFIED ID LOGIC
        -- We must prepend 'thm-' so Quarto counts it in the continuous sequence
        if not original_id:match("^thm%-") then
          local new_id = "thm-" .. original_id
          if original_id == "" then 
             new_id = "thm-" .. env_id .. "-" .. tostring(math.random(10000))
          end
          
          div.identifier = new_id
          if original_id ~= "" then
             id_map[original_id] = new_id -- Store for ref fixing
          end
        end

        -- B. HTML HANDLING
        if quarto.doc.is_format("html") then
           -- Add necessary classes for styling
           div.classes:insert("theorem")
           div.classes:insert(env_id) 
           
           -- Force Quarto to treat it as a theorem type
           div.attributes["type"] = "theorem"
           
           -- Force the Label Name (Overrides "Theorem 1.1" -> "Axiom 1.1")
           if not div.attributes["name"] then
             div.attributes["name"] = env_title
           end
        end

        -- C. LATEX HANDLING
        if quarto.doc.is_format("latex") then
          local label_cmd = ""
          if div.identifier ~= "" then
            label_cmd = "\\label{" .. div.identifier .. "}"
          end
          
          local begin_cmd = "\\begin{" .. env_id .. "}"
          if div.attributes["name"] then
            begin_cmd = begin_cmd .. "[" .. div.attributes["name"] .. "]"
          end
          
          local raw_begin = pandoc.RawBlock("latex", begin_cmd .. label_cmd)
          local raw_end = pandoc.RawBlock("latex", "\\end{" .. env_id .. "}")
          
          return { raw_begin } .. div.content .. { raw_end }
        end
        
        return div
      end
    end
  }

  -- PASS 2: FIX REFERENCES (@axm-savage -> @thm-axm-savage)
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

  -- PASS 3: LATEX HEADER (Continuous Numbering Logic)
  if quarto.doc.is_format("latex") and #envs > 0 then
    local header = ""
    local master = "theorem" -- Default master
    
    -- Check if user defined 'theorem' in their list, if so use it as master
    local user_has_theorem = false
    for _, e in ipairs(envs) do if e.id == "theorem" then user_has_theorem = true end end
    
    -- If user didn't define theorem, use the FIRST environment as the master
    local first_env = envs[1]
    if not user_has_theorem then
       master = first_env.id
    end
    
    -- Generate \newtheorem commands
    for i, e in ipairs(envs) do
      -- If this is the master, define it normally (reset by section)
      if e.id == master then
         header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    
    -- Now define the others to share the master counter
    for i, e in ipairs(envs) do
      if e.id ~= master then
         if user_has_theorem or (e.id ~= envs[1].id) then
            -- Use the shared counter
            header = header .. "\\newtheorem{" .. e.id .. "}[" .. master .. "]{" .. e.title .. "}\n"
         end
      end
    end
    
    quarto.doc.include_text("in-header", header)
  end

  return doc
end
