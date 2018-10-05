defmodule HL7.V2_5.DataTypes.Ts do
  @moduledoc false
  
  use HL7.DataType,
    fields: [
			time: nil,
			degree_of_precision: nil
    ]
end
