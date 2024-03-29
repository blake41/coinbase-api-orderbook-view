require 'faye/websocket'
require 'eventmachine'
require 'pry'
require 'pry-byebug'
require 'json'
require_relative 'gui.rb'

class OrderBook

  MAPPING = {"buy" => :bids, "sell" => :asks}
  API = "wss://ws-feed.pro.coinbase.com"

  attr_reader :aggregate_by, :book, :approx_price, :aggregated_book, :sort

  def initialize(sort)
    @book = {:bids => Hash.new(0), :asks => Hash.new(0)}
    @aggregated_book = {:bids => Hash.new(0), :asks => Hash.new(0)}
    @aggregate_by = 5
    @depth_in_hundreds = 300
    @sort = sort
  end

  def depth
    @depth_in_hundreds / aggregate_by
  end

  def run
    start_socket
  end

  def sorted_bids(orders, sort)
    mapping = {
      :quantity => Proc.new{|element| -orders[element]},
      :price => Proc.new{|element| -element}
    }
    result = orders.keys.sort_by do |element|
      mapping[sort].call(element)
    end
    result.map do |element|
      [element, orders[element]]
    end
  end

  def top_bids(bids)
    bids.first(5)
  end

  def large_bids(bids)
    bids.select {|bid| bid[1] > 10}
  end

  def close_bids(quotes)
    quotes.select {|quote| quote[0] + @depth_in_hundreds > approx_price }
  end

  def close_asks(quotes)
    quotes.select {|quote| quote[0] - @depth_in_hundreds < approx_price }
  end

  def store_snapshot(snapshot)
    [:bids, :asks].each do |type|
      snapshot[type].each do |bid|
        @book[type][bid[0].to_f] = bid[1].to_f
      end
    end
  end

  def calculate_aggregated_snapshot(snapshot)
    @approx_price = snapshot[:bids].first[0]
    @aggregated_book = {:bids => Hash.new(0), :asks => Hash.new(0)}
    [:bids, :asks].each do |type|
      snapshot[type].each do |bid|
        divisor = bid[0].to_i / aggregate_by
        key = aggregate_by * divisor
        @aggregated_book[type][key] += bid[1].to_f
      end
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
      if change[2] == 0
        @book[MAPPING[change[0]]].delete(change[1])
      else
        @book[MAPPING[change[0]]][change[1].to_f] = change[2].to_f
      end
    end
  end

  def sort_bids_by_price
    large_bids(sorted_bids(aggregated_book[:bids], :price)).first(7)
  end

  def sort_asks_by_price
    close_asks(large_bids(sorted_bids(aggregated_book[:asks], :price))).first(7)
  end

  def sort_bids_by_quantity
    close_bids(large_bids(sorted_bids(aggregated_book[:bids], :quantity))).first(5)
  end

  def sort_asks_by_quantity
    close_bids(large_bids(sorted_bids(aggregated_book[:bids], :quantity))).first(5)
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
        # binding.pry
        puts event.message
      end
      ws.on :message do |event|
        parsed = JSON.parse(event.data)
        case parsed['type']
        when "snapshot"
          store_snapshot({:bids => parsed["bids"], :asks => parsed["asks"]})
        when "l2update"
          handle_update(parsed['changes'])
          calculate_aggregated_snapshot(book)
        end
      end

      ws.on :close do |event|
        p [:close, event.code, event.reason]
        ws = nil
      end

      EventMachine.add_periodic_timer(1) do
        GUI.clear_screen
        data = {}
        if aggregated_book[:bids]
          data[:bids] = send("sort_bids_by_#{sort}")
        end
        if aggregated_book[:asks]
          data[:asks] = send("sort_asks_by_#{sort}")
        end

        @gui = GUI.new(data)
        @gui.display_table
      end
    }
  end
end

ob = OrderBook.new(ARGV[0])
ob.run
