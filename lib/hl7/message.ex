defmodule HL7.Message do
  require Logger

  @segment_terminator "\r"

  defstruct id: nil,
            created_at: nil,
            raw: nil,
            lists: nil,
            message_type: nil,
            trigger_event: nil,
            facility: nil,
            application: nil,
            message_date_time: nil,
            separators: nil,
            hl7_version: nil

  @doc """
  Creates a Message struct from a raw HL7 string. The Message will
  extract basic header information (e.g. encoding characters, message type)
  and hold the raw HL7 for further processing.
  """

  @spec new(raw_msg :: String.t()) :: %HL7.Message{lists: nil}
  def new(<<"MSH", _::binary()>> = raw_message) do
    separators = HL7.Separators.new(raw_message)

    hl7_message = %HL7.Message{
      raw: raw_message,
      separators: separators,
      created_at: DateTime.utc_now()
    }

    msh = raw_message |> get_raw_msh_segment() |> split_segment_text(separators)

    destructure(
      [
        _,
        _,
        _,
        _,
        facility,
        _,
        _,
        message_date_time,
        _,
        message_type_and_trigger_event,
        _,
        _,
        hl7_version
      ],
      msh
    )

    message_type = message_type_and_trigger_event |> get_value(0, 0)
    trigger_event = message_type_and_trigger_event |> get_value(0, 1)

    %HL7.Message{
      hl7_message
      | facility: facility |> get_value(),
        message_date_time: message_date_time |> get_value(),
        message_type: message_type,
        trigger_event: trigger_event,
        hl7_version: hl7_version |> get_value(),
        created_at: DateTime.utc_now()
    }
  end

  def new(lists) when is_list(lists) do
    [msh | other_segments] = lists
    [name, field_separator | msh_tail] = msh
    [encoding_characters | _] = msh_tail
    msh_without_field_separator = [name | msh_tail]

    [component, repeat, _escape_char, subcomponent] = String.graphemes(encoding_characters)

    join_by_character_list = [field_separator, repeat, component, subcomponent]

    raw =
      join_with_separators(
        [msh_without_field_separator | other_segments],
        [@segment_terminator | join_by_character_list]
      ) <> @segment_terminator

    HL7.Message.new(raw)
  end

  def new(raw_message) when is_binary(raw_message) do
    %HL7.InvalidMessage{
      raw: raw_message,
      created_at: DateTime.utc_now()
    }
  end

  def parse(%HL7.Message{raw: raw_message, lists: nil, separators: separators} = hl7_message) do
    lists =
      raw_message
      |> String.split(@segment_terminator, trim: true)
      |> Enum.map(&split_segment_text(&1, separators))

    %HL7.Message{hl7_message | lists: lists}
  end

  def parse(%HL7.Message{} = hl7_message) do
    hl7_message
  end

  def parse(raw_message) when is_binary(raw_message) do
    raw_message
    |> HL7.Message.new()
    |> HL7.Message.parse()
  end

  def get_segment(%HL7.Message{raw: raw_message, lists: nil}, segment_name) do
    get_segment_from_raw_message(raw_message, segment_name)
  end

  def get_segment(%HL7.Message{lists: lists}, segment_name)
      when is_list(lists) and is_binary(segment_name) do
    lists
    |> Enum.find(fn seg ->
      [s | _] = seg
      s == segment_name
    end)
  end

  def get_segment(raw_message, segment_name)
      when is_binary(raw_message) and is_binary(segment_name) do
    get_segment_from_raw_message(raw_message, segment_name)
  end

  def get_segment(nested_lists, segment_name)
      when is_list(nested_lists) and is_binary(segment_name) do
    nested_lists
    |> Enum.find(fn seg -> get_value(seg) == segment_name end)
  end

  def get_segments(%HL7.Message{raw: raw_message, lists: nil}, segment_name) do
    get_segments_from_raw_message(raw_message, segment_name)
  end

  def get_segments(%HL7.Message{lists: lists}, segment_name)
      when is_list(lists) and is_binary(segment_name) do
    lists
    |> Enum.filter(fn seg ->
      [[s] | _] = seg
      s == segment_name
    end)
  end

  def get_segments(raw_message, segment_name)
      when is_binary(raw_message) and is_binary(segment_name) do
    get_segments_from_raw_message(raw_message, segment_name)
  end

  def get_segments(nested_lists, segment_name)
      when is_list(nested_lists) and is_binary(segment_name) do
    nested_lists
    |> Enum.filter(fn seg -> get_value(seg) == segment_name end)
  end

  def get_part(%HL7.Message{lists: nil} = hl7_message, indices) when is_list(indices) do
    Logger.warn(
      "Calling HL7.Message.get_part/2 on a :raw message is not performant. Consider calling make_lists/1 if used repeatedly."
    )

    parsed_msg = parse(hl7_message)
    get_part(parsed_msg.lists, indices)
  end

  def get_part(%HL7.Message{} = hl7_message, [segment | indices])
      when is_list(indices) and is_binary(segment) do
    hl7_message
    |> get_segment(segment)
    |> get_part(indices)
  end

  def get_part(%HL7.Message{lists: lists}, indices) when is_list(indices) do
    get_part(lists, indices)
  end

  def get_part(data, []) do
    data
  end

  def get_part(data, [i | remaining_indices]) do
    case data do
      nil ->
        data

      _ when is_nil(i) ->
        data

      _ when is_binary(data) ->
        data

      _ when is_binary(i) and is_list(data) ->
        Enum.find(data, fn d -> get_value(d) == i end) |> get_part(remaining_indices)

      _ when is_integer(i) and is_list(data) ->
        Enum.at(data, i) |> get_part(remaining_indices)
    end
  end

  def get_part(data, i1 \\ nil, i2 \\ nil, i3 \\ nil, i4 \\ nil, i5 \\ nil) do
    get_part(data, [i1, i2, i3, i4, i5])
  end

  def get_value(data, i1 \\ 0, i2 \\ 0, i3 \\ 0, i4 \\ 0, i5 \\ 0) do
    get_part(data, [i1, i2, i3, i4, i5])
  end

  # -----------------
  # Private functions
  # -----------------

  defp get_raw_msh_segment(<<"MSH", _::binary()>> = raw_message) do
    raw_message
    |> String.splitter(@segment_terminator)
    |> Enum.at(0)
  end

  defp split_segment_text(<<"MSH", _rest::binary()>> = raw_text, separators) do
    raw_text
    |> strip_msh_encoding
    |> split_into_fields(separators)
    |> add_msh_encoding_fields(separators)
  end

  defp split_segment_text(raw_text, separators) do
    raw_text |> split_into_fields(separators)
  end

  defp split_into_fields(text, separators) do
    text
    |> String.split(separators.field)
    |> Enum.map(&split_with_text_delimiters(&1, separators))
  end

  defp split_with_text_delimiters("", _separators) do
    ""
  end

  defp split_with_text_delimiters(text, separators) do
    delimiters = get_delimiters_in_text(text, separators)
    text |> split_with_separators(delimiters)
  end

  defp get_delimiters_in_text(text, separators) do
    find_delimiters(text, separators.delimiter_check)
  end

  defp find_delimiters(_text, []) do
    []
  end

  defp find_delimiters(text, [split_character | remaining] = delimiters) do
    case text |> String.contains?(split_character) do
      true -> Enum.reverse(delimiters)
      false -> find_delimiters(text, remaining)
    end
  end

  defp split_with_separators("", _) do
    ""
  end

  defp split_with_separators(text, [split_character | remaining_characters]) do
    text
    |> String.split(split_character)
    |> Enum.map(&split_with_separators(&1, remaining_characters))
  end

  defp split_with_separators(text, []) do
    text
  end

  defp join_with_separators(text, _separators) when is_binary(text) do
    text
  end

  defp join_with_separators(lists, [split_character | remaining_characters]) do
    lists
    |> Enum.map(&join_with_separators(&1, remaining_characters))
    |> Enum.join(split_character)
  end

  defp strip_msh_encoding(<<"MSH", _encoding_chars::binary-size(5), msh_rest::binary>>) do
    "MSH" <> msh_rest
  end

  defp add_msh_encoding_fields([msh_name | msh_tail], separators) do
    [msh_name, separators.field, separators.encoding_characters | msh_tail]
  end

  defp get_segment_from_raw_message(raw_message, segment_name) do
    raw_message
    |> String.splitter(@segment_terminator)
    |> Stream.filter(fn segment_text -> String.length(segment_text) > 3 end)
    |> Stream.filter(fn <<message_type::binary-size(3), _::binary>> ->
      segment_name == message_type
    end)
    |> Enum.at(0)
  end

  defp get_segments_from_raw_message(raw_message, segment_name) do
    raw_message
    |> String.split(@segment_terminator)
    |> Enum.filter(fn segment_text -> String.length(segment_text) > 3 end)
    |> Enum.filter(fn <<message_type::binary-size(3), _::binary>> ->
      segment_name == message_type
    end)
  end

  defimpl String.Chars, for: HL7.Message do
    require Logger

    def to_string(%HL7.Message{} = hl7_message) do
      hl7_message.raw
    end
  end
end
