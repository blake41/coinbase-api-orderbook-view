class OrderBook

  API = "wss://ws-feed.pro.coinbase.com"

  def initialize

  end

  def run

  end

  def start_socket
    request = {
        "jsonrpc" => "2.0",
        "method" => "public/get_funding_chart_data",
        "params" => {
            "instrument_name" => "BTC-PERPETUAL",
            "length" => "8h"
        }
    }

    EM.run {
      ws = Faye::WebSocket::Client.new(API)

      EventMachine.add_periodic_timer(1) do
        begin
          ws.send(request.to_json) }
        rescue => e
          puts e.message
        end
      end

      ws.on :open do |event|
        p [:open]
      end

      ws.on :message do |event|
        parsed = JSON.parse(event.data)
        eight_hour_interest = parsed['result']['interest_8h']
        current_interest = parsed['result']['current_interest']
        if @globals[:current_interest] != current_interest
          if current_interest < 0 && @globals[:neg_funding] == false
            `say "Funding Negative"`
            @globals[:neg_funding] = true
          else
            @globals[:neg_funding] = false
          end
          display_data({eight_hour_interest: eight_hour_interest, current_interest: current_interest})
        end
        @globals[:current_interest] = current_interest
      end

      ws.on :close do |event|
        p [:close, event.code, event.reason]
        ws = nil
      end
    }
  end



end
