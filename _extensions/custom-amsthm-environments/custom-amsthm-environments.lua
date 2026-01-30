-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- ARCHITECTURE: Multi-pass filter chain to prevent Quarto AST walker crashes.

-- GLOBAL STATE (Shared across passes)
local envs = {}
local id_map = {}
local header_includes = ""

-- PASS 1: Configuration (Reads your YAML settings)
local function Pass1_Config(meta)
  local raw_config = meta['custom-amsthm'] or meta['amsthm-environments']
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
end

-- PASS 2: Block Processing (Renames IDs, Extracts Titles, Formats Output)
local function Pass2_Div(div)
  -- 1. Detect Environment
  local env = nil
  for _, e in ipairs(envs) do
    local prefix = e.id .. "-"
    if div.identifier:find("^" .. prefix) then env = e break end
    if div.classes:includes(e.id) then env = e break end
  end
  
  if not env then return nil end

  -- 2. Extract Header (Title)
  local final_title = div.attributes["name"] or env.title
  local content_subset = {}
  local start_index = 1
  
  -- Check if first block is a Header to use as title
  if #div.content > 0 and div.content[1].t == "Header" then
     if not div.attributes["name"] then
        final_title = pandoc.utils.stringify(div.content[1].content)
     end
     start_index = 2 -- Skip the header in the output
  end

  -- Safe copy of content (using standard Loop)
  for i = start_index, #div.content do
     table.insert(content_subset, div.content[i])
  end

  -- 3. Unified ID Logic (Force 'thm-' prefix)
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

  -- 4. HTML Output
  if quarto.doc.is_format("html") then
     div.classes:insert("theorem")
     div.classes:insert(env.id)
     div.attributes["type"] = "theorem"
     div.attributes["name"] = final_title
     div.content = content_subset
     return div
  end

  -- 5. LaTeX Output
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
    
    -- STABILITY FIX: Wrap in a transparent anonymous Div
    -- This prevents list-splicing crashes in Quarto's 'jog.lua'
    local container_blocks = { raw_begin }
    for _, block in ipairs(content_subset) do
      table.insert(container_blocks, block)
    end
    table.insert(container_blocks, raw_end)
    
    return pandoc.Div(container_blocks)
  end
end

-- PASS 3: Fix References (@ax-1 -> @thm-ax-1)
local function Pass3_Refs(doc)
  return doc:walk {
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
end

-- PASS 4: Header Injection (LaTeX Only)
local function Pass4_Header(doc)
  if quarto.doc.is_format("latex") and #envs > 0 then
    local header = ""
    local master = "theorem"
    local user_has_theorem = false
    
    for _, e in ipairs(envs) do if e.id == "theorem" then user_has_theorem = true end end
    if not user_has_theorem then master = envs[1].id end
    
    -- Define master (resets at section)
    for _, e in ipairs(envs) do
      if e.id == master then
         header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    -- Define others (shared counter)
    for _, e in ipairs(envs) do
      if e.id ~= master then
         if user_has_theorem or (e.id ~= envs[1].id) then
            header = header .. "\\newtheorem{" .. e.id .. "}[" .. master .. "]{" .. e.title .. "}\n"
         end
      end
    end
    
    quarto.doc.include_text("in-header", header)
  end
end

-- RETURN FILTER LIST
-- Pandoc applies these strictly in order.
return {
  { Meta = Pass1_Config },
  { Div = Pass2_Div },
  { Pandoc = Pass3_Refs },
  { Pandoc = Pass4_Header }
}
