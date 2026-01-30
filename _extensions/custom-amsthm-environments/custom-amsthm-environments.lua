-- Custom amsthm environments extension for Quarto
-- Modified to support continuous numbering across all environment types

local custom_amsthm_envs = {}
local used_override_numbers = {}  -- Track override numbers to detect duplicates
local html_counter = 0  -- Single shared counter for HTML output (continuous numbering)

-- Process metadata and set up crossref configuration
function process_custom_amsthm(meta)
  if meta["custom-amsthm"] then
    for _, custom in ipairs(meta["custom-amsthm"]) do
      local key = pandoc.utils.stringify(custom.key)
      local name = pandoc.utils.stringify(custom.name or key)
      local reference_prefix = pandoc.utils.stringify(custom["reference-prefix"] or name)
      local latex_name = pandoc.utils.stringify(custom["latex-name"] or name:lower())
      local numbered = custom.numbered == nil or custom.numbered -- default to true

      custom_amsthm_envs[key] = {
        name = name,
        reference_prefix = reference_prefix,
        latex_name = latex_name,
        numbered = numbered
      }

      if not meta.crossref then
        meta.crossref = {}
      end
      -- Set up crossref metadata for Quarto
      meta.crossref[key .. "-title"] = pandoc.MetaInlines({pandoc.Str(name)})
      meta.crossref[key .. "-prefix"] = pandoc.MetaInlines({pandoc.Str(reference_prefix)})
    end
  end

  return meta
end

-- Generate LaTeX headers with continuous numbering
function generate_latex_headers()
  local headers = {}

  -- List of Quarto's built-in theorem types that we want to make share counters
  local builtin_types = {
    "lemma", "corollary", "proposition", "conjecture",
    "definition", "example", "exercise"
  }

  -- Determine the master counter
  -- If no built-in theorems are used, we need to define our own master
  local master_latex = "theorem"
  local need_master_definition = true

  -- Check if theorem is already defined (will be if any #thm- divs exist)
  -- For now, we'll always try to make built-in counters aliases
  -- Make all built-in counters aliases of the theorem counter
  -- This is done AFTER Quarto defines them, so they'll share the same counter
  for _, builtin in ipairs(builtin_types) do
    -- Make the counter an alias: \let\c@<env>\c@theorem
    -- Wrap in conditional to avoid errors if counter doesn't exist
    table.insert(headers, "\\makeatletter")
    table.insert(headers, "\\@ifundefined{c@" .. builtin .. "}{}{\\let\\c@" .. builtin .. "\\c@" .. master_latex .. "}")
    table.insert(headers, "\\makeatother")
  end

  -- Find the first numbered custom environment
  local master_custom_key = nil
  for key, env in pairs(custom_amsthm_envs) do
    if env.numbered then
      if not master_custom_key then
        master_custom_key = key
      end
    end
  end

  if master_custom_key then
    local first_custom_env = custom_amsthm_envs[master_custom_key]

    -- First, define the first custom environment conditionally
    table.insert(headers, "\\makeatletter")
    table.insert(headers, "\\@ifundefined{c@" .. master_latex .. "}{")
    -- theorem counter doesn't exist, define first custom env as master
    table.insert(headers, "  \\newtheorem{" .. first_custom_env.latex_name .. "}{" .. first_custom_env.name .. "}[section]")
    table.insert(headers, "  \\let\\c@" .. master_latex .. "\\c@" .. first_custom_env.latex_name)
    table.insert(headers, "  \\let\\thetheorem\\the" .. first_custom_env.latex_name)
    table.insert(headers, "  \\let\\p@" .. master_latex .. "\\p@" .. first_custom_env.latex_name)
    table.insert(headers, "}{")
    -- theorem counter exists, share it
    table.insert(headers, "  \\newtheorem{" .. first_custom_env.latex_name .. "}[" .. master_latex .. "]{" .. first_custom_env.name .. "}")
    table.insert(headers, "}")
    table.insert(headers, "\\makeatother")

    -- Now define all other custom numbered environments to share with theorem
    for key, env in pairs(custom_amsthm_envs) do
      if env.numbered and key ~= master_custom_key then
        table.insert(headers, "\\newtheorem{" .. env.latex_name .. "}[" .. master_latex .. "]{" .. env.name .. "}")
      end
    end

    -- Define unnumbered custom environments
    for key, env in pairs(custom_amsthm_envs) do
      if not env.numbered then
        table.insert(headers, "\\newtheorem*{" .. env.latex_name .. "}{" .. env.name .. "}")
      end
    end
  end

  if #headers > 0 then
    return table.concat(headers, "\n")
  end
  return nil
end

-- Process divs to extract environment information
function process_divs(div)
  for key, env in pairs(custom_amsthm_envs) do
    local env_pattern = "^" .. key .. "%-"
    if div.identifier:match(env_pattern) then
      -- Extract custom title from header if present
      local title = nil
      local content_start = 1

      if #div.content > 0 and div.content[1].t == "Header" then
        title = pandoc.utils.stringify(div.content[1].content)
        content_start = 2
      end

      -- Check for override number attribute
      local override_number = div.attributes["number"]
      if override_number then
        -- Check for duplicates
        local env_override_key = key .. ":" .. override_number
        if used_override_numbers[env_override_key] then
          error("ERROR: Duplicate override number '" .. override_number .. "' for environment type '" .. env.name .. "'\n" ..
                "First use: " .. used_override_numbers[env_override_key] .. "\n" ..
                "Second use: " .. div.identifier)
        end
        used_override_numbers[env_override_key] = div.identifier
      end

      if quarto.doc.is_format("latex") then
        -- Generate LaTeX environment
        local latex_name = env.latex_name
        local blocks = pandoc.List()

        -- Handle override number
        if override_number then
          -- Temporarily redefine the counter display to show override number
          blocks:insert(pandoc.RawBlock("latex", "\\begingroup"))
          -- Redefine \thetheorem to show override number
          blocks:insert(pandoc.RawBlock("latex", "\\renewcommand{\\thetheorem}{" .. override_number .. "}"))
        end

        local begin_env = "\\begin{" .. latex_name .. "}"
        if title then
          begin_env = begin_env .. "[" .. title .. "]"
        end
        begin_env = begin_env .. "\\label{" .. div.identifier .. "}"

        blocks:insert(pandoc.RawBlock("latex", begin_env))

        -- Add content (skip header if present)
        for i = content_start, #div.content do
          blocks:insert(div.content[i])
        end

        blocks:insert(pandoc.RawBlock("latex", "\\end{" .. latex_name .. "}"))

        if override_number then
          -- Decrement the counter since we don't want override numbers to consume sequence numbers
          blocks:insert(pandoc.RawBlock("latex", "\\addtocounter{theorem}{-1}"))
          blocks:insert(pandoc.RawBlock("latex", "\\endgroup"))
        end

        return pandoc.Div(blocks)
      elseif quarto.doc.is_format("html") then
        -- For HTML output, we need to format the theorem properly
        -- since Quarto's crossref doesn't handle custom types automatically

        -- Prepare content (remove header if present)
        local body_content = pandoc.List()
        for i = content_start, #div.content do
          body_content:insert(div.content[i])
        end

        -- Add theorem class for styling
        if not div.classes:includes("theorem") then
          div.classes:insert("theorem")
        end
        if not div.classes:includes(key) then
          div.classes:insert(key)
        end

        -- Format the theorem title and number
        local display_number
        local header_text

        if override_number then
          -- Override number case - don't increment the counter
          display_number = override_number
        else
          -- Standard sequential numbering for HTML - use shared counter for continuous numbering
          html_counter = html_counter + 1
          display_number = tostring(html_counter)
        end

        -- Build header text
        header_text = env.name .. " " .. display_number
        if title then
          header_text = header_text .. " (" .. title .. ")"
        end

        -- Create formatted title
        local title_para = pandoc.Para({
          pandoc.Span(
            {pandoc.Strong({pandoc.Str(header_text)})},
            {class = "theorem-title"}
          ),
          pandoc.Space()
        })

        -- Merge with first paragraph if it exists and is a Para
        if #body_content > 0 and body_content[1].t == "Para" then
          for _, elem in ipairs(body_content[1].content) do
            title_para.content:insert(elem)
          end
          body_content:remove(1)
        end

        body_content:insert(1, title_para)
        div.content = body_content

        -- Store the number as a data attribute for potential cross-references
        div.attributes["data-number"] = display_number

        return div
      end
    end
  end

  return nil
end

-- Return filter functions
return {
  { Meta = process_custom_amsthm },
  { Div = process_divs },
  {
    Pandoc = function(doc)
      if quarto.doc.is_format("latex") then
        local header = generate_latex_headers()
        if header then
          quarto.doc.include_text("in-header", header)
        end
      end
      return doc
    end
  }
}
