defmodule HL7.V2_5.DataTypes.Ri do
  @moduledoc false
  
  use HL7.DataType,
    fields: [
			repeat_pattern: nil,
			explicit_time_interval: nil
    ]
end
