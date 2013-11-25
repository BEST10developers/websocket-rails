require 'spec_helper'

module WebsocketRails
  describe Connection do
    let(:connection_manager) { double(ConnectionManager).as_null_object }
    let(:dispatcher) { double(Dispatcher).as_null_object }
    let(:channel_manager) { double(ChannelManager).as_null_object }
    let(:event) { double(Event).as_null_object }

    before do
      connection_manager.stub(:connections).and_return({})
      dispatcher.stub(:connection_manager).and_return(connection_manager)
      Event.stub(:new_from_json).and_return(event)
    end

    subject { Connection.new(mock_request, dispatcher) }

    context "new connection" do
      it "should create a new DataStore::Connection instance" do
        subject.data_store.should be_a DataStore::Connection
      end

      it "creates a unique ID" do
        UUIDTools::UUID.stub(:random_create).and_return(1024)
        subject.id.should == 1024
      end

      it "opens a new Faye::WebSocket connection" do
        subject.websocket.should be_a Faye::WebSocket
      end

      #before do
      #  WebsocketRails.config.stub(:user_identifier).and_return(:name)
      #  WebsocketRails::DelegationController.any_instance
      #    .stub_chain(:current_user, :name)
      #    .and_return('Frank')
      #  subject
      #end

      #it "adds itself to the UserManager Hash" do
      #  WebsocketRails.users['Frank'].should == subject
      #end
    end

    describe "#bind_messager_handler" do
      it "delegates websocket events to the appropriate message handler" do
        Faye::WebSocket.any_instance.should_receive(:onmessage=)
        Faye::WebSocket.any_instance.should_receive(:onclose=)
        Faye::WebSocket.any_instance.should_receive(:onerror=)
        subject
      end
    end

    describe "#on_open" do
      it "should dispatch an on_open event" do
        on_open_event = double('event').as_null_object
        subject.stub(:send)
        Event.should_receive(:new_on_open).and_return(on_open_event)
        dispatcher.should_receive(:dispatch).with(on_open_event)
        subject.on_open
      end
    end

    describe "#on_message" do
      it "should forward the data to the dispatcher" do
        dispatcher.should_receive(:dispatch).with(event)
        subject.on_message encoded_message
      end
    end

    describe "#on_close" do
      it "should dispatch an on_close event" do
        on_close_event = double('event')
        Event.should_receive(:new_on_close).and_return(on_close_event)
        dispatcher.should_receive(:dispatch).with(on_close_event)
        subject.on_close("data")
      end
    end

    describe "#on_error" do
      it "should dispatch an on_error event" do
        subject.stub(:on_close)
        on_error_event = double('event').as_null_object
        Event.should_receive(:new_on_error).and_return(on_error_event)
        dispatcher.should_receive(:dispatch).with(on_error_event)
        subject.on_error("data")
      end

      it "should fire the on_close event" do
        data = "test_data"
        subject.should_receive(:on_close).with(data)
        subject.on_error("test_data")
      end
    end

    describe "#send_message" do
      before do
        Event.any_instance.stub(:trigger)
      end
      after do
        subject.send_message :message, "some_data"
      end

      it "creates and triggers a new event" do
        Event.any_instance.should_receive(:trigger)
      end

      it "sets it's user identifier on the event" do
        subject.stub(:user_identifier).and_return(:some_name_or_id)
        Event.should_receive(:new) do |name, options|
          options[:user_id].should == :some_name_or_id
        end.and_call_original
      end

      it "sets the connection property of the event correctly" do
        subject.stub(:user_identifier).and_return(:some_name_or_id)
        Event.should_receive(:new) do |name, options|
          options[:connection].should == subject
        end.and_call_original
      end
    end

    describe "#send" do
      it "delegates to the websocket connection" do
        subject.websocket.should_receive(:send).with(:message)
        subject.send :message
      end
    end

    describe "#close!" do
      it "delegates to the websocket connection" do
        subject.websocket.should_receive(:close)
        subject.close!
      end
    end

    describe "#user_connection?" do
      context "when a user is signed in" do
        before do
          subject.stub(:user_identifier).and_return("Jimbo Jones")
        end

        it "returns true" do
          subject.user_connection?.should == true
        end
      end

      context "when a user is signed out" do
        before do
          subject.stub(:user_identifier).and_return(nil)
        end

        it "returns true" do
          subject.user_connection?.should == false
        end
      end
    end

    describe "#user" do
      it "provides access to the current_user object" do
        user = double('User')
        subject.stub(:user_identifier).and_return true
        subject.stub_chain(:controller_delegate, :current_user).and_return user
        subject.user.should == user
      end
    end

    describe "#trigger" do
      it "passes a serialized event to the connections #send method" do
        event.stub(:serialize).and_return('test')
        subject.should_receive(:send).with "[test]"
        subject.trigger event
      end
    end

    describe "#close_connection" do
      before do
        subject.stub(:user_identifier).and_return(1)
        @connection_manager = double('connection_manager').as_null_object
        subject.stub_chain(:dispatcher, :connection_manager).and_return(@connection_manager)
      end

      it "calls delegates to the conection manager" do
        @connection_manager.should_receive(:close_connection).with(subject)
        subject.__send__(:close_connection)
      end

      it "deletes it's data_store" do
        subject.data_store.should_receive(:destroy!)
        subject.__send__(:close_connection)
      end
    end
  end
end