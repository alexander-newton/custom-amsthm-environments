-- Custom AMSTHM Environments with Continuous Numbering & Smart Configuration
-- FIXED: Reads config from metadata instead of requiring a missing module.

function Pandoc(doc)
  -- 1. READ CONFIGURATION FROM METADATA
  -- We parse _quarto.yml options into a clean Lua table
  local amsthm_environments = {}
  local meta_env = doc.meta['amsthm-environments']
  
  if meta_env then
    for _, item in ipairs(meta_env) do
      -- Handle "- {id: axiom, title: Axiom}" format (MetaMap)
      if type(item) == 'table' and item.t == 'MetaMap' then
        table.insert(amsthm_environments, {
          id = pandoc.utils.stringify(item.id), 
          title = item.title and pandoc.utils.stringify(item.title) or nil
        })
      -- Handle "- axiom" format (MetaInlines/MetaString)
      else
        table.insert(amsthm_environments, {
          id = pandoc.utils.stringify(item)
        })
      end
    end
  end

  -- Helper: Check if a list of classes contains one of our target environments
  local function get_env_info(classes)
    for _, env in ipairs(amsthm_environments) do
      local id = env.id
      if classes:includes(id) then
        local title = env.title or id:gsub("^%l", string.upper)
        return id, title
      end
    end
    return nil, nil
  end

  local id_map = {} -- Stores mapping from "ax-1" -> "thm-ax-1"
  
  -- PASS 1: Find Custom Divs, Rename IDs, and Spoof Types
  doc.blocks = doc.blocks:walk {
    Div = function(div)
      local env_id, env_title = get_env_info(div.classes)
      
      if env_id then
        local original_id = div.identifier
        
        -- STANDARD ID LOGIC: Ensure it starts with 'thm-'
        -- This forces Quarto to put it in the main numbering sequence.
        if original_id ~= "" and not original_id:match("^thm%-") then
          local new_id = "thm-" .. original_id
          div.identifier = new_id
          id_map[original_id] = new_id -- Remember this swap for Pass 2
        elseif original_id == "" then
           div.identifier = "thm-" .. env_id .. "-" .. tostring(math.random(100000))
        end

        -- HTML SPECIFIC: Spoof as Theorem for Quarto's CSS/Counter
        if quarto.doc.is_format("html") then
           div.classes:insert("theorem")
           div.attributes["type"] = "theorem"
           -- Force the display name (e.g. "Axiom 3.2")
           if not div.attributes["name"] then
             div.attributes["name"] = env_title
           end
        end

        -- LATEX SPECIFIC: Wrap in raw LaTeX environment
        if quarto.doc.is_format("latex") then
          local label_cmd = ""
          if div.identifier ~= "" then
            label_cmd = "\\label{" .. div.identifier .. "}"
          end

          local begin_cmd = "\\begin{" .. env_id .. "}"
          if div.attributes["name"] then
            begin_cmd = begin_cmd .. "[" .. div.attributes["name"] .. "]"
          end
          
          local start_env = pandoc.RawBlock("latex", begin_cmd .. label_cmd)
          local end_env = pandoc.RawBlock("latex", "\\end{" .. env_id .. "}")
          
          return { start_env } .. div.content .. { end_env }
        end
        
        return div
      end
    end
  }

  -- PASS 2: Update Citations and Links to match new IDs
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

  -- HEADER INCLUDES: Generate LaTeX definitions (Order Agnostic)
  if quarto.doc.is_format("latex") and #amsthm_environments > 0 then
    local header_includes = ""
    local master_id = nil
    local master_title = nil

    -- 1. Identify the Master Environment (Prefer 'theorem')
    for _, env in ipairs(amsthm_environments) do
      if env.id == "theorem" then
         master_id = "theorem"
         master_title = env.title or "Theorem"
         break
      end
    end

    -- If no theorem, use the first defined env
    if not master_id then
       local first = amsthm_environments[1]
       master_id = first.id
       master_title = first.title or master_id:gsub("^%l", string.upper)
    end

    -- 2. Define the Master First (Counter resets at section)
    header_includes = header_includes .. "\\newtheorem{" .. master_id .. "}{" .. master_title .. "}[section]\n"

    -- 3. Define all others (Shared Counter)
    for _, env in ipairs(amsthm_environments) do
      local env_id = env.id
      local env_title = env.title or env_id:gsub("^%l", string.upper)
      
      if env_id ~= master_id then
         -- Note: [master_id] makes them share the counter
         header_includes = header_includes .. "\\newtheorem{" .. env_id .. "}[" .. master_id .. "]{" .. env_title .. "}\n"
      end
    end
    
    quarto.doc.include_text("in-header", header_includes)
  end

  return doc
end
