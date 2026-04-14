module ApplicationHelper
  def display_meat_label(meat)
    {
      "牛" => "牛肉",
      "豚" => "豚肉",
      "鶏" => "鶏肉"
    }.fetch(meat, meat)
  end
end
