defmodule HL7.V2_3_1.DataTypes.Ei do
  @moduledoc false
  
  use HL7.DataType,
    fields: [
			entity_identifier: nil,
			namespace_id: nil,
			universal_id: nil,
			universal_id_type: nil
    ]
end
