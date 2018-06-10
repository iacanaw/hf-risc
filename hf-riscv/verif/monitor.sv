`ifndef MONITOR_SV
 `define MONITOR_SV

 `include "hfrv_interface.sv"

class Monitor_cbs;
  virtual task mem(virtual hfrv_interface.monitor iface);
  endtask
  virtual task data_access();
  endtask
  virtual task instruction(Opcode opcode, Instruction instruction, bit [31:0] instr);
  endtask
  virtual task terminated();
  endtask
endclass

typedef class Termination_monitor;
typedef class Fake_uart;
typedef class Post_instruction_monitor;

class monitor;
   virtual hfrv_interface.monitor iface;
   event   terminated;
   Monitor_cbs cbs[$];
   Termination_monitor termination_monitor;
   Post_instruction_monitor post_instruction_monitor;
   Fake_uart fake_uart;
   mailbox msgout;

   function new(virtual hfrv_interface.monitor iface, input event terminated, mailbox msgout);
      this.iface = iface;
      this.terminated = terminated;
      this.msgout = msgout;
      this.termination_monitor = new(this.terminated);
      this.fake_uart = new(msgout);
      this.post_instruction_monitor = new(cbs);
      this.cbs.push_back(this.termination_monitor);
      this.cbs.push_back(this.fake_uart);
      this.cbs.push_back(this.post_instruction_monitor);
   endfunction // new

   task run();
      fork;
         watch_mem;
         watch_terminated;
         watch_data_access;
         watch_instruction;
      join;
   endtask // run

   task watch_data_access();
      forever @(posedge iface.mem.data_access) begin
        foreach (cbs[i]) begin
         cbs[i].data_access();
        end
      end
   endtask

   task watch_instruction();
      Opcode opcode;
      Instruction instruction;
      bit[31:0] instr;

      forever @(posedge iface.mem.data_access) begin
        $cast(instr,tb_top.dut.cpu.inst_in_s);
        if ($cast(opcode, instr[6:0])) begin
          if ($cast(instruction, instr & OpcodeMask[opcode]))
          begin
            // SLLI, SRLI and SRAI mix OPP_IMM and OP: OPP_IMM OPCODE with OP mask.
            // Because of that, SRAI is always mistaken as SRLI
            if (instruction === SRLI) begin
              $cast(instruction, instr & OpcodeMask_SR_I);
            end
            foreach (cbs[i]) begin
             cbs[i].instruction(opcode, instruction, instr);
            end
          end
        end
      end
   endtask

   task watch_mem();
      forever @(iface.mem) begin
        foreach (cbs[i]) begin
         cbs[i].mem(this.iface);
        end
      end
   endtask

   task watch_terminated();
     @(terminated) begin
       foreach (cbs[i]) begin
        cbs[i].terminated();
       end
       $finish;
     end
   endtask

endclass // monitor

class Post_instruction_monitor extends Monitor_cbs;
  Monitor_cbs cbs[$];
  Snapshot pre_snapshot;
  Snapshot post_snapshot;
  bit[31:0] previous_instr;

  function new(ref Monitor_cbs cbs[$]);
    this.cbs = cbs;
  endfunction

  virtual task instruction(Opcode opcode, Instruction instruction, bit[31:0] instr);
    foreach (post_snapshot.registers[i]) begin
      post_snapshot.registers[i] = tb_top.dut.cpu.register_bank.registers[i];
    end
  endtask
endclass

class Termination_monitor extends Monitor_cbs;
  event terminated;

  function new(ref event terminated);
    this.terminated = terminated;
  endfunction

  virtual task mem(virtual hfrv_interface.monitor iface);
    super.mem(iface);
    if (iface.mem.address == 32'he0000000 && iface.mem.data_we != 4'h0)
    begin
      iface.mem.data_read <= {32{1'b0}};
      ->terminated;
    end
  endtask

endclass

class Fake_uart extends Monitor_cbs;
  string line;
  mailbox msgout;

  function new(mailbox msgout);
    this.line = "";
    this.msgout = msgout;
  endfunction

  virtual task mem(virtual hfrv_interface.monitor iface);
    super.mem(iface);
    if(iface.mem.address == 32'hf00000d0) begin
       automatic byte char = iface.mem.data_write[30:24];
       iface.mem.data_read <= {32{1'b0}};
       if (char != 8'h0A)
         line = {line, char};

       if (char == 8'h0A || line.len() == 72) begin
          this.msgout.put(line);
          line = "";
       end
    end
  endtask
endclass

`endif
