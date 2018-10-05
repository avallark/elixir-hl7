defmodule HL7.V2_4.DataTypes.Rfr do
  @moduledoc false
  alias HL7.V2_4.{DataTypes}

  use HL7.DataType,
    fields: [
			numeric_range: DataTypes.Nr,
			administrative_sex: nil,
			age_range: DataTypes.Nr,
			gestational_range: DataTypes.Nr,
			species: nil,
			racesubspecies: nil,
			conditions: nil
    ]
end
