require 'faye/websocket'
require 'eventmachine'
require 'pry'
require 'pry-byebug'
require 'json'

class OrderBook

  API = "wss://ws-feed.pro.coinbase.com"
  attr_reader :aggregate_by, :book, :approx_price, :aggregated_book
  def initialize
    @book = Hash.new(0)
    @aggregated_book = Hash.new(0)
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
      @book[bid[0].to_f] = bid[1].to_f
    end
  end

  def store_aggregated_snapshot(snapshot)
    snapshot[:bids].each do |bid|
      divisor = bid[0].to_i / aggregate_by
      key = aggregate_by * divisor
      @approx_price = key
      @aggregated_book[key] += bid[1].to_f
    end
  end

  def handle_update(update)
    grouped_elements = update.group_by {|element| element[0]}
    handle_bids(grouped_elements) if grouped_elements["buy"]
    handle_offers(grouped_elements) if grouped_elements["sell"]
  end

  def handle_bids(changes)
    handle_changes(changes["buy"])
  end

  def handle_offers(changes)
    handle_changes(changes["sell"])
  end

  def handle_changes(changes)
    changes.each do |change|
      @book
    end
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
      ws.on :error do |event|
        binding.pry
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
