w.createModule("menu")
w.require("pricing")
w.require("framework")

---@autodoc:config ignore:true
function w.menu.formatPrice(price)
  if price == nil then price = 0 end

  return w.framework:addItemDataToPrice(w.pricing.new(price):getCosts())
end

---@autodoc:config ignore:true
function w.menu.formatPrices(prices)
  if prices == nil then
    return {
      operator = "and",
      w.menu.formatPrice(0)
    }
  end

  if type(prices) ~= "table" then
    return {
      operator = "and",
      w.menu.formatPrice(prices)
    }
  end

  if w.pricing.isPriceGroup(prices) or prices.prices ~= nil or prices.operator ~= nil then
    local group = w.pricing.newGroup(prices)
    local formattedPrices = {
      operator = group.operator
    }

    for i = 1, #group.prices do
      formattedPrices[i] = group.prices[i]:getCosts()
    end

    return w.framework:addItemDataToPrice(formattedPrices)
  end

  return {
    operator = "and",
    w.menu.formatPrice(prices)
  }
end

---@autodoc:config ignore:true
function w.menu.isPriceFree(price)
  local prices = w.menu.formatPrices(price)

  return #prices == 1 and w.pricing.new({
    costs = prices[1]
  }):isFree()
end

---@autodoc:config ignore:true
function w.menu.mergePrices(...)
  local prices = { ... }
  prices.operator = "and"

  return w.pricing.newGroup(prices):compact():getCosts()
end

---@autodoc:config ignore:true
function w.menu.tax(price, percentage, roundUpItems)
  local taxPrice = w.pricing.tax(price, percentage, roundUpItems)

  return taxPrice:getCosts()
end
