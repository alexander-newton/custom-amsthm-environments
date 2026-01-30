-- Custom AMSTHM Environments: Continuous Numbering & Header Extraction
-- STABILITY FIX: Uses "Ghost Divs" to prevent Quarto AST crashes.

-- GLOBAL STATE (Populated by Config, used by Divs/Header)
local envs = {}
local id_map = {}

-- HELPER: Safe Stringify (Handles strings and Pandoc elements)
local function safe_string(x)
  if type(x) == 'string' then return x end
  if x and x.t == 'MetaString' then return x.text end
  if x and x.t == 'MetaInlines' then return pandoc.utils.stringify(x) end
  return pandoc.utils.stringify(x)
end

-- 1. CONFIGURATION PASS (Reads _quarto.yml)
local function Pass1_Config(meta)
  local raw_config = meta['custom-amsthm'] or meta['amsthm-environments']
  if raw_config then
    for _, item in ipairs(raw_config) do
      local entry = {}
      if type(item) == 'table' then
        -- Handle: - key: axm, name: Axiom
        local k = item.key or item.id
        local n = item.name or item.title
        entry.id = safe_string(k)
        entry.title = safe_string(n)
      else
        -- Handle: - axiom
        entry.id = safe_string(item)
        entry.title = entry.id:gsub("^%l", string.upper)
      end
      table.insert(envs, entry)
    end
  end
end

-- 2. DIV PROCESSING PASS (The Core Logic)
local function Pass2_Div(div)
  -- A. Detect Environment
  local env = nil
  for _, e in ipairs(envs) do
    local prefix = e.id .. "-"
    if div.identifier:find("^" .. prefix) then env = e break end
    if div.classes:includes(e.id) then env = e break end
  end
  
  if not env then return nil end

  -- B. Header Extraction (Check first block)
  local final_title = div.attributes["name"] or env.title
  if #div.content > 0 and div.content[1].t == "Header" then
     -- If user didn't manually set name, use header text
     if not div.attributes["name"] then
        final_title = pandoc.utils.stringify(div.content[1].content)
     end
     -- Remove the header from the content
     div.content:remove(1)
  end

  -- C. ID Standardization (Enforce 'thm-' prefix)
  local original_id = div.identifier
  local new_id = original_id
  
  if not original_id:match("^thm%-") then
    new_id = "thm-" .. original_id
    if original_id == "" then 
       new_id = "thm-" .. env.id .. "-" .. tostring(math.random(10000))
    end
    -- Map old ID to new ID for reference fixing
    if original_id ~= "" then
       id_map[original_id] = new_id 
    end
  end
  
  -- D. OUTPUT GENERATION
  if quarto.doc.is_format("html") then
     -- HTML: Update Div attributes and return it
     div.identifier = new_id
     div.classes:insert("theorem")
     div.classes:insert(env.id)
     div.attributes["type"] = "theorem"
     div.attributes["name"] = final_title
     return div
  
  elseif quarto.doc.is_format("latex") then
    -- LATEX: "Ghost Div" Strategy
    -- 1. Create Raw LaTeX Blocks
    local label_cmd = ""
    if new_id ~= "" then label_cmd = "\\label{" .. new_id .. "}" end
    
    local begin_text = "\\begin{" .. env.id .. "}"
    if final_title then begin_text = begin_text .. "[" .. final_title .. "]" end
    
    local raw_begin = pandoc.RawBlock("latex", begin_text .. label_cmd)
    local raw_end = pandoc.RawBlock("latex", "\\end{" .. env.id .. "}")
    
    -- 2. Inject into the Div's content
    div.content:insert(1, raw_begin)
    div.content:insert(raw_end)
    
    -- 3. Strip Div attributes to make it a transparent container
    -- This ensures Pandoc renders the content (our latex + body) but NO surrounding div tags
    div.identifier = ""
    div.classes = {}
    div.attributes = {}
    
    -- 4. Return the Single Div (Safe!)
    return div
  end
end

-- 3. REFERENCE FIXING PASS (@ax-1 -> @thm-ax-1)
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

-- 4. HEADER GENERATION PASS (LaTeX Only)
local function Pass4_Header(doc)
  if quarto.doc.is_format("latex") and #envs > 0 then
    local header = ""
    local master = "theorem"
    local user_has_theorem = false
    
    -- Determine Master Counter
    for _, e in ipairs(envs) do if e.id == "theorem" then user_has_theorem = true end end
    if not user_has_theorem then master = envs[1].id end
    
    -- Write Master Definition
    for _, e in ipairs(envs) do
      if e.id == master then
         header = header .. "\\newtheorem{" .. e.id .. "}{" .. e.title .. "}[section]\n"
      end
    end
    -- Write Shared Definitions
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

-- EXECUTION ORDER
-- We return a list of separate filters to let Pandoc chain them safely.
return {
  { Meta = Pass1_Config },    -- Load config first
  { Div = Pass2_Div },        -- Process Divs (depends on config)
  { Pandoc = Pass3_Refs },    -- Fix refs (depends on Div processing)
  { Pandoc = Pass4_Header }   -- Write header (depends on config)
}
