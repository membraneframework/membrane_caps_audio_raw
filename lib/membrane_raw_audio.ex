defmodule Membrane.RawAudio do
  @moduledoc """
  This module contains a definition and related functions for struct `t:#{inspect(__MODULE__)}.t/0`,
  describing a format of raw audio stream with interleaved channels.
  """

  alias __MODULE__.SampleFormat
  alias Membrane.Time

  @compile {:inline,
            [
              sample_size: 1,
              frame_size: 1,
              sample_type_float?: 1,
              sample_type_fixed?: 1,
              big_endian?: 1,
              little_endian?: 1,
              signed?: 1,
              unsigned?: 1,
              sample_to_value: 2,
              value_to_sample: 2,
              value_to_sample_check_overflow: 2,
              sample_min: 1,
              sample_max: 1,
              silence: 1,
              frames_to_bytes: 2,
              bytes_to_frames: 3,
              frames_to_time: 3,
              time_to_frames: 3,
              bytes_to_time: 3,
              time_to_bytes: 3
            ]}

  # Amount of channels inside a frame.
  @type channels_t :: pos_integer

  # Sample rate of the audio.
  @type sample_rate_t :: pos_integer

  @type t :: %Membrane.RawAudio{
          channels: channels_t,
          sample_rate: sample_rate_t,
          sample_format: SampleFormat.t()
        }

  @enforce_keys [:channels, :sample_rate, :sample_format]
  defstruct @enforce_keys

  @doc """
  Returns how many bytes are needed to store a single sample.

  Inlined by the compiler
  """
  @spec sample_size(t) :: integer
  def sample_size(%__MODULE__{sample_format: format}) do
    {_type, size, _endianness} = SampleFormat.to_tuple(format)
    size |> div(8)
  end

  @doc """
  Returns how many bytes are needed to store a single frame.

  Inlined by the compiler
  """
  @spec frame_size(t) :: integer
  def frame_size(%__MODULE__{channels: channels} = format) do
    sample_size(format) * channels
  end

  @doc """
  Determines if the sample values are represented by a floating point number.

  Inlined by the compiler.
  """
  @spec sample_type_float?(t) :: boolean
  def sample_type_float?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:f, _size, _endianness} -> true
      _otherwise -> false
    end
  end

  @doc """
  Determines if the sample values are represented by an integer.

  Inlined by the compiler.
  """
  @spec sample_type_fixed?(t) :: boolean
  def sample_type_fixed?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:s, _size, _endianness} -> true
      {:u, _size, _endianness} -> true
      _otherwise -> false
    end
  end

  @doc """
  Determines if the sample values are represented by a number in little endian byte ordering.

  Inlined by the compiler.
  """
  @spec little_endian?(t) :: boolean
  def little_endian?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {_type, _size, :le} -> true
      {_type, _size, :any} -> true
      _otherwise -> false
    end
  end

  @doc """
  Determines if the sample values are represented by a number in big endian byte ordering.

  Inlined by the compiler.
  """
  @spec big_endian?(t) :: boolean
  def big_endian?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {_type, _size, :be} -> true
      {_type, _size, :any} -> true
      _otherwise -> false
    end
  end

  @doc """
  Determines if the sample values are represented by a signed number.

  Inlined by the compiler.
  """
  @spec signed?(t) :: boolean
  def signed?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:s, _size, _endianness} -> true
      {:f, _size, _endianness} -> true
      _otherwise -> false
    end
  end

  @doc """
  Determines if the sample values are represented by an unsigned number.

  Inlined by the compiler.
  """
  @spec unsigned?(t) :: boolean
  def unsigned?(%__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:u, _size, _endianness} -> true
      _otherwise -> false
    end
  end

  @doc """
  Converts one raw sample into its numeric value, interpreting it for given sample format.

  Inlined by the compiler.
  """
  @spec sample_to_value(bitstring, t) :: number
  def sample_to_value(sample, %__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:s, size, endianness} when endianness in [:le, :any] ->
        <<value::integer-size(size)-little-signed>> = sample
        value

      {:u, size, endianness} when endianness in [:le, :any] ->
        <<value::integer-size(size)-little-unsigned>> = sample
        value

      {:s, size, :be} ->
        <<value::integer-size(size)-big-signed>> = sample
        value

      {:u, size, :be} ->
        <<value::integer-size(size)-big-unsigned>> = sample
        value

      {:f, size, :le} ->
        <<value::float-size(size)-little>> = sample
        value

      {:f, size, :be} ->
        <<value::float-size(size)-big>> = sample
        value
    end
  end

  @doc """
  Converts value into one raw sample, encoding it with the given sample format.

  Inlined by the compiler.
  """
  @spec value_to_sample(number, t) :: binary
  def value_to_sample(value, %__MODULE__{sample_format: format}) do
    case SampleFormat.to_tuple(format) do
      {:s, size, endianness} when endianness in [:le, :any] ->
        <<value::integer-size(size)-little-signed>>

      {:u, size, endianness} when endianness in [:le, :any] ->
        <<value::integer-size(size)-little-unsigned>>

      {:s, size, :be} ->
        <<value::integer-size(size)-big-signed>>

      {:u, size, :be} ->
        <<value::integer-size(size)-big-unsigned>>

      {:f, size, :le} ->
        <<value::float-size(size)-little>>

      {:f, size, :be} ->
        <<value::float-size(size)-big>>
    end
  end

  @doc """
  Same as value_to_sample/2, but also checks for overflow.
  Returns {:error, :overflow} if overflow happens.

  Inlined by the compiler.
  """
  @spec value_to_sample_check_overflow(number, t) :: {:ok, binary} | {:error, :overflow}
  def value_to_sample_check_overflow(value, format) do
    if sample_min(format) <= value and sample_max(format) >= value do
      {:ok, value_to_sample(value, format)}
    else
      {:error, :overflow}
    end
  end

  @doc """
  Returns minimum sample value for given sample format.

  Inlined by the compiler.
  """
  @spec sample_min(t) :: number
  def sample_min(%__MODULE__{sample_format: format}) do
    import Bitwise

    case SampleFormat.to_tuple(format) do
      {:u, _size, _endianness} -> 0
      {:s, size, _endianness} -> -(1 <<< (size - 1))
      {:f, _size, _endianness} -> -1.0
    end
  end

  @doc """
  Returns maximum sample value for given sample format.

  Inlined by the compiler.
  """
  @spec sample_max(t) :: number
  def sample_max(%__MODULE__{sample_format: format}) do
    import Bitwise

    case SampleFormat.to_tuple(format) do
      {:s, size, _endianness} -> (1 <<< (size - 1)) - 1
      {:u, size, _endianness} -> (1 <<< size) - 1
      {:f, _size, _endianness} -> 1.0
    end
  end

  @doc """
  Returns one 'silent' sample, that is value of zero in given format' sample format.

  Inlined by the compiler.
  """
  @spec silence(t) :: binary
  def silence(%__MODULE__{sample_format: :s8}), do: <<0>>
  def silence(%__MODULE__{sample_format: :u8}), do: <<128>>
  def silence(%__MODULE__{sample_format: :s16le}), do: <<0, 0>>
  def silence(%__MODULE__{sample_format: :u16le}), do: <<0, 128>>
  def silence(%__MODULE__{sample_format: :s16be}), do: <<0, 0>>
  def silence(%__MODULE__{sample_format: :u16be}), do: <<128, 0>>
  def silence(%__MODULE__{sample_format: :s24le}), do: <<0, 0, 0>>
  def silence(%__MODULE__{sample_format: :u24le}), do: <<0, 0, 128>>
  def silence(%__MODULE__{sample_format: :s24be}), do: <<0, 0, 0>>
  def silence(%__MODULE__{sample_format: :u24be}), do: <<128, 0, 0>>
  def silence(%__MODULE__{sample_format: :s32le}), do: <<0, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :u32le}), do: <<0, 0, 0, 128>>
  def silence(%__MODULE__{sample_format: :s32be}), do: <<0, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :u32be}), do: <<128, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :f32le}), do: <<0, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :f32be}), do: <<0, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :f64le}), do: <<0, 0, 0, 0, 0, 0, 0, 0>>
  def silence(%__MODULE__{sample_format: :f64be}), do: <<0, 0, 0, 0, 0, 0, 0, 0>>

  @doc """
  Returns a binary which corresponds to the silence during the given interval
  of time in given format' sample format

  ## Examples:
  The following code generates the silence for the given format

      iex> alias Membrane.RawAudio
      iex> format = %RawAudio{sample_rate: 48_000, sample_format: :s16le, channels: 2}
      iex> silence = RawAudio.silence(format, 100 |> Membrane.Time.microseconds())
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  """
  @spec silence(t, Time.non_neg_t(), (float -> integer)) :: binary
  def silence(%__MODULE__{} = format, time, round_f \\ &(&1 |> :math.ceil() |> trunc))
      when time >= 0 do
    length = time_to_frames(time, format, round_f)
    silence(format) |> String.duplicate(format.channels * length)
  end

  @doc """
  Converts frames to bytes in given format.

  Inlined by the compiler.
  """
  @spec frames_to_bytes(non_neg_integer, t) :: non_neg_integer
  def frames_to_bytes(frames, %__MODULE__{} = format) when frames >= 0 do
    frames * frame_size(format)
  end

  @doc """
  Converts bytes to frames in given format.

  Inlined by the compiler.
  """
  @spec bytes_to_frames(non_neg_integer, t, (float -> integer)) :: non_neg_integer
  def bytes_to_frames(bytes, %__MODULE__{} = format, round_f \\ &trunc/1) when bytes >= 0 do
    (bytes / frame_size(format)) |> round_f.()
  end

  @doc """
  Converts time in Membrane.Time units to frames in given format.

  Inlined by the compiler.
  """
  @spec time_to_frames(Time.non_neg_t(), t, (float -> integer)) :: non_neg_integer
  def time_to_frames(time, %__MODULE__{} = format, round_f \\ &(&1 |> :math.ceil() |> trunc))
      when time >= 0 do
    (time * format.sample_rate / Time.second()) |> round_f.()
  end

  @doc """
  Converts frames to time in Membrane.Time units in given format.

  Inlined by the compiler.
  """
  @spec frames_to_time(non_neg_integer, t, (float -> integer)) :: Time.non_neg_t()
  def frames_to_time(frames, %__MODULE__{} = format, round_f \\ &trunc/1)
      when frames >= 0 do
    (frames * Time.second() / format.sample_rate) |> round_f.()
  end

  @doc """
  Converts time in Membrane.Time units to bytes in given format.

  Inlined by the compiler.
  """
  @spec time_to_bytes(Time.non_neg_t(), t, (float -> integer)) :: non_neg_integer
  def time_to_bytes(time, %__MODULE__{} = format, round_f \\ &(&1 |> :math.ceil() |> trunc))
      when time >= 0 do
    time_to_frames(time, format, round_f) |> frames_to_bytes(format)
  end

  @doc """
  Converts bytes to time in Membrane.Time units in given format.

  Inlined by the compiler.
  """
  @spec bytes_to_time(non_neg_integer, t, (float -> integer)) :: Time.non_neg_t()
  def bytes_to_time(bytes, %__MODULE__{} = format, round_f \\ &trunc/1)
      when bytes >= 0 do
    frames_to_time(bytes |> bytes_to_frames(format), format, round_f)
  end
end
