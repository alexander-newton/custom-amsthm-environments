-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- "Atomic Container" Version: Prevents Quarto 1.8+ crashes by returning single Divs.

-- 1. READ CONFIGURATION
-- We prefer 'custom-amsthm', but support 'amsthm-environments' too.
local envs = {}
local function read_config(meta)
  local raw_config = meta['custom-amsthm'] or meta['amsthm-environments']
  if raw_config then
    for _, item in ipairs(raw_config) do
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
end

-- Helper: Find which environment a Div belongs to
local function detect_environment(div)
  for _, env in ipairs(envs) do
    -- Check ID prefix (e.g., #axm-...)
    if div.identifier:find("^" .. env.id .. "%-") then return env end
    -- Check Class (e.g., .axm)
    if div.classes:includes(env.id) then return env end
  end
  return nil
end

-- 2. MAIN DIV PROCESSOR
local function process_div(div)
  local env = detect_environment(div)
  if not env then return nil end

  -- A. TITLE EXTRACTION (Look for ##### Header)
  local final_title = div.attributes["name"] or env.title
  local content_subset = pandoc.List()
  local start_index = 1
  
  if #div.content > 0 and div.content[1].t == "Header" then
    if not div.attributes["name"] then
      final_title = pandoc.utils.stringify(div.content[1].content)
    end
    start_index = 2 -- Skip the header in the output
  end

  -- Copy content safely
  for i = start_index, #div.content do
    content_subset:insert(div.content[i])
  end

  -- B. ID GENERATION (Force 'thm-' prefix)
  local original_id = div.identifier
  local new_id = original_id
  
  if not original_id:match("^thm%-") then
    new_id = "thm-" .. original_id
    if original_id == "" then 
       new_id = "thm-" .. env.id .. "-" .. tostring(math.random(10000))
    end
  end

  -- C. OUTPUT: HTML
  if quarto.doc.is_format("html") then
    -- Modify in place for HTML
    div.identifier = new_id
    div.classes:insert("theorem")
    div.classes:insert(env.id)
    div.attributes["type"] = "theorem"
    div.attributes["name"] = final_title
    div.content = content_subset
    return div
  end

  -- D. OUTPUT: LATEX
  if quarto.doc.is_format("latex") then
    -- Generate Raw LaTeX
    local label_cmd = ""
    if new_id ~= "" then label_cmd = "\\label{" .. new_id .. "}" end
    
    local begin_cmd = "\\begin{" .. env.id .. "}"
    if final_title and final_title ~= "" then
      begin_cmd = begin_cmd .. "[" .. final_title .. "]"
    end
    
    local raw_begin = pandoc.RawBlock("latex", begin_cmd .. label_cmd)
    local raw_end = pandoc.RawBlock("latex", "\\end{" .. env.id .. "}")

    -- Build a NEW Container Div
    -- We wrap the result in a generic Div with NO attributes.
    -- Pandoc renders this as a transparent container (just the content).
    local container_blocks = pandoc.List()
    container_blocks:insert(raw_begin)
    container_blocks:extend(content_subset)
    container_blocks:insert(raw_end)
    
    return pandoc.Div(container_blocks)
  end
  
  return nil
end

-- 3. REFERENCE FIXER (@ax-1 -> @thm-ax-1)
local function fix_references(doc)
  -- Build map of old IDs to new IDs
  local id_map = {}
  
  -- Scan for our divs to build the map
  doc.blocks:walk {
    Div = function(div)
      local env = detect_environment(div)
      if env and div.identifier ~= "" and not div.identifier:match("^thm%-") then
         id_map[div.identifier] = "thm-" .. div.identifier
      end
    end
  }
  
  -- Apply fixes to Cites and Links
  return doc:walk {
    Cite = function(cite)
      for _, c in ipairs(cite.citations) do
        if id_map[c.id] then c.id = id_map[c.id] end
      end
      return cite
    end,
    Link = function(link)
      local hash = link.target:match("^#(.*)")
      if hash and id_map[hash] then link.target = "#" .. id_map[hash] end
      return link
    end
  }
end

-- 4. HEADER GENERATOR (LaTeX)
local function generate_header(doc)
  if quarto.doc.is_format("latex") and #envs > 0 then
    local header = ""
    local master = "theorem"
    local has_theorem = false
    
    for _, e in ipairs(envs) do if e.id == "theorem" then has_theorem = true end end
    if not has_theorem then master = envs[1].id end
    
    -- Master definition
    for _, e in ipairs(envs) do
      if e.id == master then
        header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    -- Dependent definitions
    for _, e in ipairs(envs) do
      if e.id ~= master then
        local parent = (has_theorem or e.id ~= envs[1].id) and master or nil
        if parent then
           header = header .. "\\newtheorem{" .. e.id .. "}[" .. parent .. "]{" .. e.title .. "}\n"
        end
      end
    end
    quarto.doc.include_text("in-header", header)
  end
end

-- REGISTER FILTERS
return {
  { Meta = read_config },
  { Div = process_div },
  { Pandoc = fix_references },
  { Pandoc = generate_header }
}
