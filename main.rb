require 'faye/websocket'
require 'eventmachine'
require 'pry'
require 'pry-byebug'
require 'json'

@globals = {neg_funding: false, current_interest: 7}

def convert_to_percent(float)
  percentage_value = float * 100
  percentage_value.round(7)
end

def funding_rate_display(data)
  "#{convert_to_percent(data)}%"
end

def display_data(data)
  puts "Funding Rate: #{funding_rate_display(data[:current_interest])}"
  puts "8 Hour Average Rate: #{funding_rate_display(data[:eight_hour_interest])}"
  puts "----------------------------------------"
end

def add_timer

  request = {
      "jsonrpc" => "2.0",
      "method" => "public/get_funding_chart_data",
      "params" => {
          "instrument_name" => "BTC-PERPETUAL",
          "length" => "8h"
      }
  }.to_json

  EventMachine.add_periodic_timer(1) do
    begin
      ws.send(request)
    rescue => e
      binding.pry
      puts e.message
    end
  end
end

def ws
  @globals[:ws]
end

def ws_message

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
end

def ws_open
  ws.on :open do |event|
    p [:open]
  end
end

def ws_close
  ws.on :close do |event|
    p [:close, event.code, event.reason]
    @globals[:ws] = nil
  end
end


EM.run {
  @globals[:ws] = Faye::WebSocket::Client.new('wss://www.deribit.com/ws/api/v2')

  add_timer
  ws_message
  ws_open
  ws_close

}
