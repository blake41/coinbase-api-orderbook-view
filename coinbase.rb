require 'faye/websocket'
require 'eventmachine'
require 'pry'
require 'pry-byebug'
require 'json'

class OrderBook

  API = "wss://ws-feed.pro.coinbase.com"
  attr_reader :aggregate_by, :book, :approx_price
  def initialize
    @book = Hash.new(0)
    @aggregate_by = 5
    @depth_in_hundreds = 300
  end

  def depth
    @depth_in_hundreds / aggregate_by
  end

  def run
    start_socket
  end

  def sorted_bids
    result = book.keys.first(depth).sort_by do |element|
      -book[element]
    end.map do |element|
      [element, book[element]]
    end
  end

  def top_bids(bids)
    bids.first(5)
  end

  def large_bids(bids)
    bids.select {|bid| bid[1] > 10}
  end

  def store_snapshot(snapshot)
    snapshot[:bids].each do |bid|
      divisor = bid[0].to_i / aggregate_by
      key = aggregate_by * divisor
      @approx_price = key
      @book[key] += bid[1].to_f
    end
  end

  def handle_update(update)

  end

  def start_socket
    request = {
      "type"=>"subscribe",
       "product_ids"=>["BTC-USD"],
       "channels" =>
        ["level2",
         "heartbeat",
         {"name"=>"ticker", "product_ids"=>["BTC-USD"]}
        ]
    }.to_json

    EM.run {
      ws = Faye::WebSocket::Client.new(API)

      ws.send(request)

      ws.on :open do |event|
        p [:open]
      end

      ws.on :message do |event|
        parsed = JSON.parse(event.data)
        case parsed['type']
        when "snapshot"
          store_snapshot({:bids => parsed["bids"], :asks => parsed["asks"]})
        when "l2update"
          handle_update(parsed['changes'])
        end
      end

      ws.on :close do |event|
        p [:close, event.code, event.reason]
        ws = nil
      end

      EventMachine.add_periodic_timer(1) do
        puts large_bids(sorted_bids)
        puts "--------------------------------"
      end
    }
  end
end

ob = OrderBook.new
ob.run
