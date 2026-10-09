// UVM-style constructs: must not crash and must stay balanced.
class my_driver extends uvm_driver #(my_item);
  `uvm_component_utils(my_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_item tr;
    forever begin
      seq_item_port.get_next_item(tr);
      drive(tr);
      seq_item_port.item_done();
    end
  endtask

  virtual function drive(my_item tr);
    assert (tr != null) else $error("null item");
  endfunction
endclass

module tb_top;
  initial begin
    #10ns;
    $display("hello %0d", 42);
    $finish;
  end
endmodule
