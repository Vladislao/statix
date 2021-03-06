defmodule Statix.Packet do
  @moduledoc false

  use Bitwise

  otp_release = :erlang.system_info(:otp_release)
  @addr_family if(otp_release >= '19', do: [1], else: [])

  @spec header({integer(), integer(), integer(), integer()}, integer()) :: [byte(), ...]
  def header({n1, n2, n3, n4}, port) do
    @addr_family ++
      [
        band(bsr(port, 8), 0xFF),
        band(port, 0xFF),
        band(n1, 0xFF),
        band(n2, 0xFF),
        band(n3, 0xFF),
        band(n4, 0xFF)
      ]
  end

  @spec build(any(), :counter | :gauge | :histogram | :set | :timing, any(), any(), keyword()) ::
          [...]
  def build(header, name, key, val, options) do
    case Keyword.get(options, :telegraf, false) do
      true ->
        [header, key]
        |> set_option([:tags, :telegraf], options[:tags])
        |> Kernel.++([?:, val, ?|, metric_type(name)])
        |> set_option([:sample_rate, :telegraf], options[:sample_rate])

      _ ->
        [header, key, ?:, val, ?|, metric_type(name)]
        |> set_option([:sample_rate, :statsd], options[:sample_rate])
        |> set_option([:tags, :statsd], options[:tags])
    end
  end

  metrics = %{
    counter: "c",
    gauge: "g",
    histogram: "h",
    timing: "ms",
    set: "s"
  }

  for {name, type} <- metrics do
    defp metric_type(unquote(name)), do: unquote(type)
  end

  defp set_option(packet, _kind, nil) do
    packet
  end

  defp set_option(packet, [:sample_rate, _], sample_rate) when is_float(sample_rate) do
    [packet | ["|@", :erlang.float_to_binary(sample_rate, [:compact, decimals: 2])]]
  end

  defp set_option(packet, [:tags, :statsd], tags) when is_list(tags) do
    [packet | ["|#", Enum.join(tags, ",")]]
  end

  defp set_option(packet, [:tags, :telegraf], tags) when is_list(tags) do
    [packet | [",", tags |> Enum.join(",")]]
  end
end
