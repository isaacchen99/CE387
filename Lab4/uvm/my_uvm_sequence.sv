import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
    logic [23:0] image_pixel;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(image_pixel, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    task body();
        my_uvm_transaction tx;
        int in_file, n_bytes = 0, i = 0;
        logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];
        logic [23:0] pixel;

        // Stage 1: Opening the file
        `uvm_info("SEQ_RUN", $sformatf("Starting sequence: Loading file %s...", IMG_IN_NAME), UVM_LOW);
        in_file = $fopen(IMG_IN_NAME, "rb");
        if (!in_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", IMG_IN_NAME));
        end
        `uvm_info("SEQ_RUN", $sformatf("File %s opened successfully.", IMG_IN_NAME), UVM_LOW);

        // Stage 2: Reading the BMP header
        `uvm_info("SEQ_RUN", "Reading BMP header...", UVM_LOW);
        n_bytes = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);
        if (!n_bytes) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to read header data from %s...", IMG_IN_NAME));
        end
        `uvm_info("SEQ_RUN", $sformatf("BMP header read successfully (%0d bytes).", n_bytes), UVM_LOW);

        // Stage 3: Processing pixel data
        while (!$feof(in_file) && i < BMP_DATA_SIZE) begin
          tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
          start_item(tx);

          n_bytes = $fread(pixel, in_file, BMP_HEADER_SIZE + i, BYTES_PER_PIXEL);
          if (n_bytes != BYTES_PER_PIXEL) begin
              `uvm_warning("SEQ_RUN", $sformatf("Incomplete pixel data read at offset %0d.", BMP_HEADER_SIZE + i));
          end

          tx.image_pixel = pixel;
          finish_item(tx);

          if (((i / BYTES_PER_PIXEL) % 10) == 0) begin
              real percent;
              percent = (i * 100.0) / BMP_DATA_SIZE;
              `uvm_info("SEQ_RUN", 
                  $sformatf("Processed transaction %0d; Completion: %0.2f%%", (i / BYTES_PER_PIXEL), percent), 
                  UVM_LOW);
          end
          
          i += BYTES_PER_PIXEL;
      end

        // Stage 4: Closing the file
        `uvm_info("SEQ_RUN", $sformatf("All pixel data processed. Closing file %s...", IMG_IN_NAME), UVM_LOW);
        $fclose(in_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;