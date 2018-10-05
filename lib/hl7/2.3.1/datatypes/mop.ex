defmodule HL7.V2_3_1.DataTypes.Mop do
  @moduledoc false
  
  use HL7.DataType,
    fields: [
			money_or_percentage_indicator: nil,
			money_or_percentage_quantity: nil
    ]
end
