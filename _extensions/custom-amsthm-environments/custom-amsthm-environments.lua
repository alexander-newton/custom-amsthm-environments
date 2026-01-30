-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- Features:
-- 1. Continuous numbering (Theorem 3.1, Axiom 3.2)
-- 2. "Spoofs" custom types as Theorems in HTML to use Quarto's referencing
-- 3. Extracts headers (### My Title) to use as the environment title

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

  -- Helper: Match a Div to an environment by Class or ID
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
        -- A. HEADER EXTRACTION (New Feature)
        -- Check if the first block is a Header. If so, use it as the title.
        if #div.content > 0 and div.content[1].t == "Header" then
           local header = div.content[1]
           -- Only extract if user hasn't already provided a name="" attribute
           if not div.attributes["name"] then
              div.attributes["name"] = pandoc.utils.stringify(header.content)
           end
           -- Remove the header from the content body
           div.content:remove(1)
        end

        local original_id = div.identifier
        local env_id = env.id
        local env_title = env.title
        
        -- B. UNIFIED ID LOGIC
        if not original_id:match("^thm%-") then
          local new_id = "thm-" .. original_id
          if original_id == "" then 
             new_id = "thm-" .. env_id .. "-" .. tostring(math.random(10000))
          end
          div.identifier = new_id
          if original_id ~= "" then
             id_map[original_id] = new_id 
          end
        end

        -- C. HTML HANDLING
        if quarto.doc.is_format("html") then
           div.classes:insert("theorem")
           div.classes:insert(env_id) 
           div.attributes["type"] = "theorem"
           
           -- If we extracted a header, 'name' is already set. 
           -- If not, use the default environment title (e.g. "Axiom")
           if not div.attributes["name"] then
             div.attributes["name"] = env_title
           end
        end

        -- D. LATEX HANDLING
        if quarto.doc.is_format("latex") then
          local label_cmd = ""
          if div.identifier ~= "" then
            label_cmd = "\\label{" .. div.identifier .. "}"
          end
          
          local begin_cmd = "\\begin{" .. env_id .. "}"
          -- Inject the extracted title [Name] if it exists
          if div.attributes["name"] then
            begin_cmd = begin_cmd .. "[" .. div.attributes["name"] .. "]"
          end
          
          local raw_begin = pandoc.RawBlock("latex", begin_cmd .. label_cmd)
          local raw_end = pandoc.RawBlock("latex", "\\end{" .. env_id .. "}")
          
          -- Use pandoc.List to avoid concatenation errors
          local new_content = pandoc.List()
          new_content:insert(raw_begin)
          new_content:extend(div.content)
          new_content:insert(raw_end)
          
          return new_content
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
    
    for i, e in ipairs(envs) do
      if e.id == master then
         header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    
    for i, e in ipairs(envs) do
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
