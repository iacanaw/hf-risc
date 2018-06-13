class Timemachine;
  Snapshot snapshot[$];

  function bit isInstruction(int timecounter);
    if (snapshot[timecounter].data_access == 1)
      return 1;
    if (timecounter > 0)
      if (snapshot[timecounter-1].data_access == 1)
        return 1;
    return 0;
  endfunction

endclass

function Instruction getInstruction(Snapshot snap);
  automatic Opcode opcode = getOpcode(snap);
  automatic Instruction instruction;
  automatic logic [31:0] instr = getInstr(snap);

  $cast(instruction, instr & OpcodeMask[opcode]);
  // SLLI, SRLI and SRAI mix OPP_IMM and OP: OPP_IMM OPCODE with OP mask.
  // Because of that, SRAI is always mistaken as SRLI
  if (instruction === SRLI) begin
    $cast(instruction, instr & OpcodeMask_SR_I);
  end
  return instruction;

endfunction

function Opcode getOpcode(Snapshot snap);
  automatic Opcode result;
  automatic logic [31:0] instr = getInstr(snap);
  $cast(result, instr[6:0]);
  return result;
endfunction

function logic [31:0] getInstr(Snapshot snap);
  logic [31:0] result;
  result = {<<4{snap.data_read}};
  return result;
endfunction

function logic [31:0] getImm(Snapshot snap);
  automatic logic [31:0] result = 0;
  automatic logic [31:0] instr = getInstr(snap);
  case(OpcodeFormat[instr[6:0]])
    R_type: return result;
    I_type: begin
      result[31:11] = {21{instr[31]}}; //sign extension
      result[10:5]  = instr[30:25];
      result[4:1]   = instr[24:21];
      result[0]     = instr[20];
      return result;
    end
    S_type: begin
      result[31:11] = {21{instr[31]}}; //sign extension
      result[10:5]  = instr[30:25];
      result[4:1]   = instr[11:8];
      result[0]     = instr[7];
      return result;
    end
    B_type: begin
      result[31:12] = {20{instr[31]}}; //sign extension
      result[11]    = instr[7];
      result[10:5]  = instr[30:25];
      result[4:1]   = instr[11:8];
      result[0]     = 0;
      return result;
    end
    U_type: begin
      result[31]    = instr[31];
      result[30:20] = instr[30:20];
      result[19:12] = instr[19:12];
      result[11:0]  = 0;
      return result;
    end
    J_type: begin
      result[31:20] = {12{instr[31]}}; //sign extension
      result[19:12] = instr[19:12];
      result[11]    = instr[20];
      result[10:5]  = instr[30:25];
      result[4:1]   = instr[24:21];
      result[0]     = 0;
      return result;
    end
    E_type: return result;
    default: $error("Instruction type not expected for opcode %7b", instr[6:0]);
  endcase
endfunction
