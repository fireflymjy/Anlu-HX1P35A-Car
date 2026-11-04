module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    input [3:0]     I_mode          ,
    input  wire [1:0] I_lane_bias    ,
    input  wire       I_lane_force   ,
    input           I_key0_raw      ,
    output          O_mode_inc      ,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready        ,
    output [11:0]   O_red_x_min     ,
    output [11:0]   O_red_x_max     ,
    output [11:0]   O_red_y_min     ,
    output [11:0]   O_red_y_max     ,
    output          O_red_valid     ,
    output [11:0]   O_grn_x_min     ,
    output [11:0]   O_grn_x_max     ,
    output [11:0]   O_grn_y_min     ,
    output [11:0]   O_grn_y_max     ,
    output          O_grn_valid     ,
    output [11:0]   O_yel_x_min     ,
    output [11:0]   O_yel_x_max     ,
    output [11:0]   O_yel_y_min     ,
    output [11:0]   O_yel_y_max     ,
    output          O_yel_valid     ,
    output [11:0]   O_red_cx, O_red_cy,
    output          O_red_track_valid,
    output [11:0]   O_blu_cx, O_blu_cy,
    output          O_blu_track_valid,
    output [11:0]   O_blu_x_min     ,
    output [11:0]   O_blu_x_max     ,
    output [11:0]   O_blu_y_min     ,
    output [11:0]   O_blu_y_max     ,
    output          O_blu_valid     ,
    output          O_motion_valid  ,
    output [1:0]    O_motion_box_num,
    output [2:0]    O_sign_type     ,

    output [35:0]   O_sd_geo        ,
    output [11:0]   O_lane_center   ,
    output [11:0]   O_lane_offset   ,
    output [11:0]   O_lane_heading  ,
    output          O_lane_valid    ,
    output          O_lane_lost     ,
    output          O_lane_junction ,
    output          O_lane_far_ok   ,
    output          O_lane_corner   ,
    output [10:0]   O_corner_y      ,
    output [1:0]    O_shape         ,
    output          O_hollow
);

  wire         m_aixs_tvalid;
  wire [127:0] m_aixs_tdata;
  wire         m_aixs_tuser;
  wire         m_aixs_tlast;
  wire         m_aixs_tready;
  wire [ 95:0] m_aixs_tdata_96;

  wire         edge_O_tlast;
  wire         edge_O_tuser;
  wire [ 95:0] edge_O_tdata;
  wire         edge_O_tvalid;
  wire [  1:0] edge_O_hi;

  wire         fill_O_tlast;
  wire         fill_O_tuser;
  wire [ 95:0] fill_O_tdata;
  wire         fill_O_tvalid;

  wire         gray_O_tlast;
  wire         gray_O_tuser;
  wire [ 95:0] gray_O_tdata;
  wire         gray_O_tvalid;

  wire [95:0] mux_O_tdata;
  wire        mux_O_tvalid;
  wire        mux_O_tlast;
  wire        mux_O_tuser;

  wire         awb_O_tlast;
  wire         awb_O_tuser;
  wire [ 95:0] awb_O_tdata;

  wire [ 95:0] sb1_tdata, sb2_tdata;
  wire        sb1_tvalid, sb2_tvalid, sb1_tuser, sb2_tuser, sb1_tlast, sb2_tlast;
  wire         awb_O_tvalid;
  wire         awb_O_tready;

  wire [31:0] color_red_cnt, color_red_xsum, color_red_ysum;
  wire [31:0] color_blu_cnt, color_blu_xsum, color_blu_ysum;

  wire [31:0] color_yel_cnt, color_yel_xsum, color_yel_ysum;
  wire        frame_start_colordet;

  wire [95:0] bin_O_tdata;
  wire        bin_O_tvalid;
  wire        bin_O_tuser;
  wire        bin_O_tlast;

  wire         awb_O_tuser_128;
  wire         awb_O_tvalid_128;
  wire [127:0] awb_O_tdata_128;

  reg [10:0] x_grp;
  reg [10:0] y_pos;

  wire [95:0] gam_O_tdata;
  wire        gam_O_tvalid, gam_O_tuser, gam_O_tlast;

  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          x_grp <= 11'd0;
          y_pos <= 11'd0;
      end
      else if (gam_O_tvalid) begin
          if (gam_O_tlast) begin
              x_grp <= 11'd0;
              if (y_pos >= 11'd719)
                  y_pos <= 11'd0;
              else
                  y_pos <= y_pos + 11'd1;
          end
          else begin
              if (x_grp >= 11'd319)
                  x_grp <= 11'd0;
              else
                  x_grp <= x_grp + 11'd1;
          end
      end
  end

  wire [10:0] S_x_grp = gam_O_tlast ? 11'd0 : x_grp;

  assign awb_O_tready = O_tready;

  wire [95:0] md_O_tdata;
  wire        md_O_tvalid, md_O_tuser, md_O_tlast;

  wire is_motion = (I_mode == 4'd3);
  wire is_fill   = (I_mode == 4'd7);

  wire [35:0] sd_geo;

  assign mux_O_tdata  = (I_mode == 4'd1) ? edge_O_tdata  :
                        (I_mode == 4'd5) ? bin_O_tdata   :
                        (I_mode == 4'd4) ? md_O_tdata    :
                        is_fill          ? fill_O_tdata  :
                        (I_mode == 4'd8) ? gray_O_tdata  :
                        (I_mode == 4'd2) ? gam_O_tdata   :
                        (I_mode == 4'd6) ? awb_O_tdata   :
                        gam_O_tdata;
  assign mux_O_tvalid = (I_mode == 4'd1) ? edge_O_tvalid :
                        (I_mode == 4'd5) ? bin_O_tvalid  :
                        (I_mode == 4'd4) ? md_O_tvalid   :
                        is_fill          ? fill_O_tvalid :
                        (I_mode == 4'd8) ? gray_O_tvalid :
                        (I_mode == 4'd2) ? gam_O_tvalid  :
                        (I_mode == 4'd6) ? awb_O_tvalid  :
                        gam_O_tvalid;
  assign mux_O_tlast  = (I_mode == 4'd1) ? edge_O_tlast  :
                        (I_mode == 4'd5) ? bin_O_tlast   :
                        (I_mode == 4'd4) ? md_O_tlast    :
                        is_fill          ? fill_O_tlast  :
                        (I_mode == 4'd8) ? gray_O_tlast  :
                        (I_mode == 4'd2) ? gam_O_tlast   :
                        (I_mode == 4'd6) ? awb_O_tlast   :
                        gam_O_tlast;
  assign mux_O_tuser  = (I_mode == 4'd1) ? edge_O_tuser  :
                        (I_mode == 4'd5) ? bin_O_tuser   :
                        (I_mode == 4'd4) ? md_O_tuser    :
                        is_fill          ? fill_O_tuser  :
                        (I_mode == 4'd8) ? gray_O_tuser  :
                        (I_mode == 4'd2) ? gam_O_tuser   :
                        (I_mode == 4'd6) ? awb_O_tuser   :
                        gam_O_tuser;

  wire [39:0] raw_pre_tdata ;
  wire        raw_pre_tvalid;
  wire        raw_pre_tuser ;
  wire        raw_pre_tlast ;
  wire        raw_pre_tready;

  wire [9:0]  S_isp_blk  = 10'd16;
  wire [7:0]  S_isp_gn   = 8'd17;
  wire [1:0]  S_isp_gidx = 2'd3;
  wire [2:0]  S_isp_sat  = 3'd0;
  wire [2:0]  S_isp_wbr  = 3'd4;
  wire [2:0]  S_isp_wbg  = 3'd4;
  wire [2:0]  S_isp_wbb  = 3'd4;

  reg  S_isp_rdy;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) S_isp_rdy <= 1'b0;
      else          S_isp_rdy <= 1'b1;
  end

  wire [95:0] gam1_O_tdata ;
  wire        gam1_O_tvalid;
  wire        gam1_O_tuser ;
  wire        gam1_O_tlast ;

  isp_raw_pre #(
      .BLACK_LEVEL_DEF (10'd16),
      .GAIN_NUM_DEF    (8'd17 ),
      .SHIFT_BITS      (4'd6  )
  ) u_isp_raw_pre (
      .I_clk         (axi4s_video_aclk),
      .I_rst_n       (I_rst_n),
      .I_tdata       (I_tdata ),
      .I_tvalid      (I_tvalid),
      .I_tuser       (I_tuser ),
      .I_tlast       (I_tlast ),
      .I_tready      (I_tready),
      .I_black_level (S_isp_blk),
      .I_gain_num    (S_isp_gn ),
      .O_tdata       (raw_pre_tdata ),
      .O_tvalid      (raw_pre_tvalid),
      .O_tuser       (raw_pre_tuser ),
      .O_tlast       (raw_pre_tlast ),
      .O_tready      (raw_pre_tready)
  );

  demosaic #(
      .IMG_HEIGHT          (720 ),
      .IMG_WIDTH           (1280),
      .data_complete_delay (50  ),
      .BAYER_MODE          ("BGGR")
  )
  u_demosaic
  (
      .I_clk               (axi4s_video_aclk),
      .I_rst_n             (I_rst_n),
      .axi4s_video_tdata   (raw_pre_tdata ),
      .axi4s_video_tdest   (I_tdest),
      .axi4s_video_tlast   (raw_pre_tlast ),
      .axi4s_video_tvalid  (raw_pre_tvalid),
      .axi4s_video_tuser   (raw_pre_tuser ),
      .axi4s_video_tready  (raw_pre_tready),
      .O_tlast             (m_aixs_tlast),
      .O_tuser             (m_aixs_tuser),
      .O_tdata             (m_aixs_tdata),
      .O_tvalid            (m_aixs_tvalid),
      .O_tready            (m_aixs_tready)
  );

  data128_96 u_data128_96 (
      .I_tdata(m_aixs_tdata),
      .O_tdata(m_aixs_tdata_96)
  );

  awb #(
      .IMG_HEIGHT(720 ),
      .IMG_WIDTH (1280)
  ) u_awb (
      .I_clk   (axi4s_video_aclk),
      .I_rst_n (I_rst_n),
      .I_tlast (m_aixs_tlast),
      .I_tuser (m_aixs_tuser),
      .I_tdata (m_aixs_tdata_96),
      .I_tvalid(m_aixs_tvalid),
      .I_tready(m_aixs_tready),
      .O_tlast (awb_O_tlast ),
      .O_tuser (awb_O_tuser ),
      .O_tdata (awb_O_tdata ),
      .O_tvalid(awb_O_tvalid),
      .O_tready(awb_O_tready)
  );

  isp_gamma #(
      .GAMMA_IDX_DEF (2'd3)
  ) u_isp_gamma (
      .I_clk       (axi4s_video_aclk),
      .I_rst_n     (I_rst_n),
      .I_tdata     (awb_O_tdata ),
      .I_tvalid    (awb_O_tvalid),
      .I_tuser     (awb_O_tuser ),
      .I_tlast     (awb_O_tlast ),
      .I_tready    (            ),
      .I_gamma_idx (S_isp_gidx ),
      .O_tdata     (gam1_O_tdata ),
      .O_tvalid    (gam1_O_tvalid),
      .O_tuser     (gam1_O_tuser ),
      .O_tlast     (gam1_O_tlast ),
      .O_tready    (S_isp_rdy  )
  );

  isp_ccm #(
      .CCM_PRESET  (0)
  ) u_isp_ccm (
      .I_clk      (axi4s_video_aclk),
      .I_rst_n    (I_rst_n),
      .I_tdata    (gam1_O_tdata ),
      .I_tvalid   (gam1_O_tvalid),
      .I_tuser    (gam1_O_tuser ),
      .I_tlast    (gam1_O_tlast ),
      .I_tready   (             ),
      .I_sat_idx  (S_isp_sat   ),
      .I_wb_r_sel (S_isp_wbr   ),
      .I_wb_g_sel (S_isp_wbg   ),
      .I_wb_b_sel (S_isp_wbb   ),
      .O_tdata    (gam_O_tdata ),
      .O_tvalid   (gam_O_tvalid),
      .O_tuser    (gam_O_tuser ),
      .O_tlast    (gam_O_tlast ),
      .O_tready   (S_isp_rdy   )
  );

  color_detect #(
      .IMG_WIDTH          (1280),
      .IMG_HEIGHT         (720),

      .USE_RATIO_CLS      (1'b1),
      .V_MIN              (8'd60),
      .S_SHIFT            (4'd1),
      .H_TAN_NUM          (4'd2),
      .H_TAN_DEN          (4'd7),
    .MIN_PIXELS         (16'd1500),

    .GROUP_VOTE         (3'd3),
      .CONFIRM_FRAMES     (4'd2),
      .BBOX_MIN_W         (12'd16),
      .BBOX_MIN_H         (12'd16),
      .BBOX_MAX_W         (12'd800),
      .BBOX_MAX_H         (12'd600),

    .MIN_PIXELS_BLUE    (16'd1000),

      .V_MAX_BLUE         (8'd255),
      .BLUE_DIFF_SHIFT    (4'd1),
      .FILL_SHIFT_BLUE    (4'd3),
      .FILL_SHIFT_OTHER   (4'd3)
  )  u_color_detect (
      .I_clk        (axi4s_video_aclk),
      .I_rst_n      (I_rst_n),
      .I_tdata      (gam_O_tdata),
      .I_tvalid     (gam_O_tvalid),
      .I_tuser      (gam_O_tuser),
      .I_tlast      (gam_O_tlast),
      .I_x_grp      (S_x_grp),
      .I_y_pos      (y_pos),

      .O_red_x_min  (O_red_x_min), .O_red_x_max  (O_red_x_max),
      .O_red_y_min  (O_red_y_min), .O_red_y_max  (O_red_y_max),
      .O_red_cnt    (color_red_cnt),
      .O_red_xsum   (color_red_xsum), .O_red_ysum (color_red_ysum),
      .O_red_valid  (O_red_valid),

      .O_blu_x_min  (O_blu_x_min), .O_blu_x_max  (O_blu_x_max),
      .O_blu_y_min  (O_blu_y_min), .O_blu_y_max  (O_blu_y_max),
      .O_blu_cnt    (color_blu_cnt),
      .O_blu_xsum   (color_blu_xsum), .O_blu_ysum (color_blu_ysum),
      .O_blu_valid  (O_blu_valid),

      .O_grn_x_min  (O_grn_x_min), .O_grn_x_max  (O_grn_x_max),
      .O_grn_y_min  (O_grn_y_min), .O_grn_y_max  (O_grn_y_max),
      .O_grn_cnt    (), .O_grn_xsum   (), .O_grn_ysum   (), .O_grn_valid  (O_grn_valid),

      .O_yel_x_min  (O_yel_x_min), .O_yel_x_max  (O_yel_x_max),
      .O_yel_y_min  (O_yel_y_min), .O_yel_y_max  (O_yel_y_max),

      .O_yel_cnt    (color_yel_cnt), .O_yel_xsum (color_yel_xsum), .O_yel_ysum (color_yel_ysum),
      .O_yel_valid  (O_yel_valid)
  );

  reg frame_start_colordet_d;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n)
          frame_start_colordet_d <= 1'b0;
      else
          frame_start_colordet_d <= gam_O_tuser;
  end
  assign frame_start_colordet = gam_O_tuser & ~frame_start_colordet_d;

  target_tracker #(
      .LOST_THRESH (4'd3)
  ) u_target_tracker (
      .I_clk         (axi4s_video_aclk),
      .I_rst_n       (I_rst_n),
      .I_frame_start (frame_start_colordet),

      .I_red_valid   (O_blu_valid),
      .I_red_x_min   (O_blu_x_min), .I_red_x_max (O_blu_x_max),
      .I_red_y_min   (O_blu_y_min), .I_red_y_max (O_blu_y_max),
      .I_red_xsum    (color_blu_xsum), .I_red_ysum (color_blu_ysum),
      .I_red_cnt     (color_blu_cnt),

      .I_blu_valid   (1'b0),
      .I_blu_x_min   (12'd0), .I_blu_x_max (12'd0),
      .I_blu_y_min   (12'd0), .I_blu_y_max (12'd0),
      .I_blu_xsum    (32'd0), .I_blu_ysum  (32'd0), .I_blu_cnt (32'd0),

      .I_yel_valid   (1'b0),
      .I_yel_x_min   (12'd0), .I_yel_x_max (12'd0),
      .I_yel_y_min   (12'd0), .I_yel_y_max (12'd0),
      .I_yel_xsum    (32'd0), .I_yel_ysum  (32'd0), .I_yel_cnt (32'd0),

      .I_grn_valid   (1'b0),
      .I_grn_x_min   (12'd0), .I_grn_x_max (12'd0),
      .I_grn_y_min   (12'd0), .I_grn_y_max (12'd0),
      .I_grn_xsum    (32'd0), .I_grn_ysum  (32'd0), .I_grn_cnt (32'd0),

      .O_red_cx      (O_red_cx),      .O_red_cy      (O_red_cy),
      .O_red_bbox_cx (),              .O_red_bbox_cy (),
      .O_red_track_valid (O_red_track_valid),

      .O_blu_cx      (O_blu_cx),      .O_blu_cy      (O_blu_cy),
      .O_blu_bbox_cx (),              .O_blu_bbox_cy (),
      .O_blu_track_valid (O_blu_track_valid),

      .O_yel_cx      (), .O_yel_cy      (), .O_yel_bbox_cx (), .O_yel_bbox_cy (), .O_yel_track_valid (),
      .O_grn_cx      (), .O_grn_cy      (), .O_grn_bbox_cx (), .O_grn_bbox_cy (), .O_grn_track_valid ()
  );

  edge_detect_96 #(
      .IMG_WIDTH  (1280),
      .IMG_HEIGHT (720),
      .EDGE_TH    (11'd40),
      .FILL_TH    (11'd120)
  ) u_edge_detect_96 (
      .I_clk    (axi4s_video_aclk),
      .I_rst_n  (I_rst_n),
      .I_tlast  (gam_O_tlast),
      .I_tuser  (gam_O_tuser),
      .I_tdata  (gam_O_tdata),
      .I_tvalid (gam_O_tvalid),
      .I_tready (1'b1),
      .O_tlast  (edge_O_tlast),
      .O_tuser  (edge_O_tuser),
      .O_tdata  (edge_O_tdata),
      .O_tvalid (edge_O_tvalid),
      .O_tready (),
      .O_hi     (edge_O_hi)
  );

  edge_fill u_edge_fill (
      .I_clk      (axi4s_video_aclk),
      .I_rst_n    (I_rst_n),
      .I_edge_pix (edge_O_tdata),
      .I_src_pix  (gam_O_tdata),
      .I_hi       (edge_O_hi),
      .I_tvalid   (edge_O_tvalid),
      .I_tuser    (edge_O_tuser),
      .I_tlast    (edge_O_tlast),
      .I_style    (I_mode == 4'd7 ? 2'd1 : 2'd0),
      .O_tdata    (fill_O_tdata),
      .O_tvalid   (fill_O_tvalid),
      .O_tuser    (fill_O_tuser),
      .O_tlast    (fill_O_tlast)
  );

  blur3_h u_blur3_h (
      .I_clk    (axi4s_video_aclk),
      .I_rst_n  (I_rst_n),
      .I_tdata  (awb_O_tdata),
      .I_tvalid (awb_O_tvalid),
      .I_tuser  (awb_O_tuser),
      .I_tlast  (awb_O_tlast),
      .O_tdata  (md_O_tdata),
      .O_tvalid (md_O_tvalid),
      .O_tuser  (md_O_tuser),
      .O_tlast  (md_O_tlast)
  );

  gray_96 u_gray_96 (
      .I_clk    (axi4s_video_aclk),
      .I_rst_n  (I_rst_n),
      .I_tdata  (gam_O_tdata ),
      .I_tvalid (gam_O_tvalid),
      .I_tuser  (gam_O_tuser ),
      .I_tlast  (gam_O_tlast ),
      .O_tdata  (gray_O_tdata),
      .O_tvalid (gray_O_tvalid),
      .O_tuser  (gray_O_tuser),
      .O_tlast  (gray_O_tlast)
  );

  blur121_h u_blur1 (
      .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
      .I_tdata(awb_O_tdata), .I_tvalid(awb_O_tvalid), .I_tuser(awb_O_tuser), .I_tlast(awb_O_tlast),
      .O_tdata(sb1_tdata), .O_tvalid(sb1_tvalid), .O_tuser(sb1_tuser), .O_tlast(sb1_tlast)
  );
  blur121_h u_blur2 (
      .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
      .I_tdata(sb1_tdata), .I_tvalid(sb1_tvalid), .I_tuser(sb1_tuser), .I_tlast(sb1_tlast),
      .O_tdata(sb2_tdata), .O_tvalid(sb2_tvalid), .O_tuser(sb2_tuser), .O_tlast(sb2_tlast)
  );

  lane_detect #(
      .IMG_WIDTH  (1280),
      .IMG_HEIGHT (720),
      .Y_ROW0     (11'd320), .Y_ROW1 (11'd400),
      .Y_ROW2     (11'd620), .Y_ROW3 (11'd680),
      .GRAD_TH    (9'd20),
      .WIN        (10'd200),
      .BIAS_STEP  (11'd160),

      .DARK_TH    (8'd70),
      .CORNER_RUN (12'd300),
      .CORNER_MIN_ROW (11'd400)
  ) u_lane_detect (
      .I_clk           (axi4s_video_aclk),
      .I_rst_n         (I_rst_n),
      .I_tdata         (md_O_tdata),
      .I_tvalid        (md_O_tvalid),
      .I_tuser         (md_O_tuser),
      .I_bias          (I_lane_bias),
      .I_force_search  (I_lane_force),
      .O_lane_center   (O_lane_center),
      .O_lane_offset   (O_lane_offset),
      .O_lane_heading  (O_lane_heading),
      .O_lane_valid    (O_lane_valid),
      .O_lane_lost     (O_lane_lost),
      .O_lane_junction (O_lane_junction),
      .O_lane_far_ok   (O_lane_far_ok),
      .O_lane_corner   (O_lane_corner),
      .O_corner_y      (O_corner_y)
  );

    wire [2:0]  sd_sign_type;
    wire [1:0]  sd_shape;
    wire        sd_hollow;

     sign_detect #(
         .IMG_WIDTH  (1280),
        .MIN_BLUE   (16'd180),
        .MIN_WHITE  (16'd20),

         .WHITE_MIN  (8'd20),

         .COLOR_DIFF (8'd50),
         .BOX_MIN    (12'd8),
         .BOX_MAX    (12'd1280)
     ) u_sign_detect (
         .I_clk        (axi4s_video_aclk),
         .I_rst_n      (I_rst_n),

         .I_tdata      (sb2_tdata),
         .I_tvalid     (sb2_tvalid),
         .I_tuser      (sb2_tuser),
         .O_sign_type  (sd_sign_type),
         .O_shape      (sd_shape),
         .O_hollow     (sd_hollow),
         .O_sd_geo     (sd_geo)
     );

    assign O_sd_geo = sd_geo;

  assign O_sign_type = (I_mode == 3'd6) ? sd_sign_type : 3'd0;

    assign O_shape     = (I_mode == 3'd6) ? sd_shape     : 2'd0;
    assign O_hollow    = (I_mode == 3'd6) ? sd_hollow    : 1'b0;

binarize #(

      .THRESHOLD (8'd135)
  ) u_binarize (
      .I_clk    (axi4s_video_aclk),
      .I_rst_n  (I_rst_n),
      .I_tdata  (gam_O_tdata ),
      .I_tvalid (gam_O_tvalid),
      .I_tuser  (gam_O_tuser ),
      .I_tlast  (gam_O_tlast ),
      .O_tdata  (bin_O_tdata),
      .O_tvalid (bin_O_tvalid),
      .O_tuser  (bin_O_tuser),
      .O_tlast  (bin_O_tlast)
  );

  reg  [8:0]  L1_x;
  reg  [1:0]  L1_line;
  reg  [95:0] L1_buf [0:319];
  reg  [95:0] L1_q;

  always @(posedge axi4s_video_aclk) begin
      L1_q <= L1_buf[L1_x];
  end
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          L1_x    <= 9'd0;
          L1_line <= 2'd0;
      end
      else if (mux_O_tuser) begin
          L1_x    <= 9'd0;
          L1_line <= 2'd0;
      end
      else if (mux_O_tvalid) begin
          if (L1_x == 9'd319) begin
              L1_x    <= 9'd0;
              L1_line <= (L1_line >= 2'd2) ? 2'd2 : (L1_line + 2'd1);
          end
          else begin
              L1_x <= L1_x + 9'd1;
          end
          if (L1_line == 2'd2) begin
              L1_buf[L1_x] <= mux_O_tdata;
          end
      end
  end

  wire [95:0] S_out_pre = (L1_line <= 2'd1) ? L1_q : mux_O_tdata;

  reg k0_s1, k0_s2;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin k0_s1 <= 1'b1; k0_s2 <= 1'b1; end
      else begin k0_s1 <= I_key0_raw; k0_s2 <= k0_s1; end
  end
  wire key_down = ~k0_s2;

  wire anim_fp = mux_O_tuser;
  reg [15:0] press_cnt;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) press_cnt <= 16'd0;
      else if (anim_fp) press_cnt <= key_down ? (press_cnt + 16'd1) : 16'd0;
  end

  reg key_down_d;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) key_down_d <= 1'b0;
      else key_down_d <= key_down;
  end
  wire key_release = key_down_d & ~key_down;

  localparam A_IDLE = 1'b0, A_RUN = 1'b1;
  localparam [1:0] B_IDLE=2'd0, B_CONTRACT=2'd1, B_HOLD=2'd2, B_EXPAND=2'd3;
  reg st_a;
  reg [1:0] st_b;
  reg [10:0] rad;
  reg [4:0]  wd;

  wire anim_idle   = (st_a == A_IDLE) && (st_b == B_IDLE);
  wire short_press = key_release && (press_cnt < 16'd30) && anim_idle;

  reg short_req;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) short_req <= 1'b0;
      else if (short_press) short_req <= 1'b1;
      else if (anim_fp && (st_a == A_IDLE) && (st_b == B_IDLE)) short_req <= 1'b0;
  end
  wire long_press  = (press_cnt == 16'd30) && anim_idle;

  reg mode_tog;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) mode_tog <= 1'b0;
      else if (short_press) mode_tog <= ~mode_tog;
  end
  assign O_mode_inc = mode_tog;

  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          st_a <= A_IDLE; st_b <= B_IDLE; rad <= 11'd0; wd <= 5'd0;
      end else if (anim_fp) begin

          if (st_a == A_IDLE) begin
              if (short_req && (st_b == B_IDLE)) begin
                  st_a <= A_RUN; rad <= 11'd0; wd <= 5'd0;
              end
          end else begin
              wd <= wd + 5'd1;
              if ((rad >= 11'd855) || (wd >= 5'd30)) begin
                  st_a <= A_IDLE; rad <= 11'd0;
              end else rad <= rad + 11'd45;
          end

          if (st_b == B_IDLE) begin
              if (long_press && (st_a == A_IDLE)) begin
                  st_b <= B_CONTRACT; rad <= 11'd900; wd <= 5'd0;
              end
          end else if (st_b == B_CONTRACT) begin
              if (!key_down) begin st_b <= B_EXPAND; wd <= 5'd0; end
              else if ((rad <= 11'd45) || (wd >= 5'd30)) begin
                  st_b <= B_HOLD; rad <= 11'd0; wd <= 5'd0;
              end else begin
                  rad <= rad - 11'd45; wd <= wd + 5'd1;
              end
          end else if (st_b == B_HOLD) begin
              if (!key_down) begin st_b <= B_EXPAND; wd <= 5'd0; end
          end else begin
              wd <= wd + 5'd1;
              if ((rad >= 11'd855) || (wd >= 5'd30)) begin
                  st_b <= B_IDLE; rad <= 11'd0;
              end else rad <= rad + 11'd45;
          end
      end
  end

  reg [10:0] ax_grp, ay_pos;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin ax_grp <= 11'd0; ay_pos <= 11'd0; end
      else if (mux_O_tvalid) begin
          if (mux_O_tlast) begin
              ax_grp <= 11'd0;
              ay_pos <= (ay_pos >= 11'd719) ? 11'd0 : (ay_pos + 11'd1);
          end else begin
              ax_grp <= (ax_grp >= 11'd319) ? 11'd0 : (ax_grp + 11'd1);
          end
      end
  end

  reg [95:0] bse_d1, bse_d2;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin bse_d1 <= 96'd0; bse_d2 <= 96'd0; end
      else begin bse_d1 <= gam_O_tdata; bse_d2 <= bse_d1; end
  end

  (* ram_style = "block" *) reg [95:0] lbuf [0:639];
  reg [9:0] lw;
  reg [95:0] lbuf_q;
  wire [9:0] lr = ((I_mode == 4'd1) || (I_mode == 4'd7)) ? lw : (lw - 10'd320);

  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          lw <= 10'd0;
          lbuf_q <= 96'd0;
      end else if (mux_O_tvalid) begin
          lbuf[lw] <= bse_d2;
          lbuf_q   <= lbuf[lr];
          lw <= (lw >= 10'd639) ? 10'd0 : (lw + 10'd1);
      end
  end

  wire [95:0] base_tap =
      ((I_mode == 4'd1) || (I_mode == 4'd7) || (I_mode == 4'd2) ||
       (I_mode == 4'd4) || (I_mode == 4'd5)) ? lbuf_q : bse_d2;

  wire [11:0] xc  = {ax_grp[9:0], 2'b00};
  wire [11:0] yc  = {1'b0, ay_pos};
  wire [11:0] dxc = (xc > 12'd640) ? (xc - 12'd640) : (12'd640 - xc);
  wire [11:0] dyc = (yc > 12'd360) ? (yc - 12'd360) : (12'd360 - yc);
  wire [11:0] d_sq  = (dxc > dyc) ? dxc : dyc;
  wire [11:0] d_dia = dxc + dyc;

  reg [11:0] d_sq_r, d_dia_r;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin d_sq_r <= 12'd0; d_dia_r <= 12'd0; end
      else begin d_sq_r <= d_sq; d_dia_r <= d_dia; end
  end

  wire [11:0] rad12 = {1'b0, rad};
  wire [11:0] rad5  = rad12 + 12'd5;
  wire b_on = (st_b != B_IDLE);
  wire a_on = (st_a != A_IDLE);
  wire [95:0] WHT = {4{24'hFFFFFF}};

  wire [95:0] anim_pix =
      b_on ? ((d_dia_r <= rad5) ? ((d_dia_r <= rad12) ? S_out_pre : WHT) : base_tap) :
      a_on ? ((d_sq_r  <= rad5) ? ((d_sq_r  <= rad12) ? S_out_pre : WHT) : base_tap) :
             S_out_pre;

  wire [95:0] S_out_pix = anim_pix;

  wire        mb_box_en;
  wire [11:0] mb_x0, mb_x1, mb_y0, mb_y1;
  wire        mb_alarm;
  wire        b1_en, b2_en;
  wire [11:0] b1x0, b1x1, b1y0, b1y1;
  wire [11:0] b2x0, b2x1, b2y0, b2y1;

  motion_box u_motion_box (
      .I_clk        (axi4s_video_aclk),
      .I_rst_n      (I_rst_n),
      .I_tdata      (gam_O_tdata),
      .I_tvalid     (gam_O_tvalid),
      .I_tuser      (gam_O_tuser),
      .I_tlast      (gam_O_tlast),
      .O_box_en     (mb_box_en),
      .O_box_x0     (mb_x0),
      .O_box_x1     (mb_x1),
      .O_box_y0     (mb_y0),
      .O_box_y1     (mb_y1),
      .O_alarm      (mb_alarm),
      .O_b1_en      (b1_en),
      .O_b1_x0      (b1x0), .O_b1_x1 (b1x1), .O_b1_y0 (b1y0), .O_b1_y1 (b1y1),
      .O_b2_en      (b2_en),
      .O_b2_x0      (b2x0), .O_b2_x1 (b2x1), .O_b2_y0 (b2y0), .O_b2_y1 (b2y1)
  );

  assign O_motion_valid   = mb_alarm;
  assign O_motion_box_num = {1'b0, mb_box_en} + {1'b0, b1_en} + {1'b0, b2_en};

  reg [10:0] oxc;
  reg [9:0]  oyc;
  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
      if (!I_rst_n) begin
          oxc <= 11'd0;
          oyc <= 10'd0;
      end
      else if (mux_O_tvalid) begin
          if (mux_O_tuser) begin
              oxc <= 11'd0;
              oyc <= 10'd0;
          end
          else if (mux_O_tlast) begin
              oxc <= 11'd0;
              oyc <= (oyc >= 10'd719) ? 10'd0 : (oyc + 10'd1);
          end
          else begin
              oxc <= oxc + 11'd1;
          end
      end
  end

  wire osd_on = is_motion;

  wire [23:0] box_col   = 24'h00FF00;

  localparam [11:0] BOX_THICK = 12'd5;

  function F_rect;
      input [11:0] x, y, x0, x1, y0, y1;
      begin
          F_rect = (x >= x0) && (x <= x1) && (y >= y0) && (y <= y1) &&
                   (((x - x0) < BOX_THICK) || ((x1 - x) < BOX_THICK) ||
                    ((y - y0) < BOX_THICK) || ((y1 - y) < BOX_THICK));
      end
  endfunction

  function F_in_box;
      input [11:0] x;
      input [11:0] y;
      begin
          F_in_box = osd_on && ( (mb_box_en && F_rect(x,y,mb_x0,mb_x1,mb_y0,mb_y1)) ||
                                 (b1_en && F_rect(x,y,b1x0,b1x1,b1y0,b1y1)) ||
                                 (b2_en && F_rect(x,y,b2x0,b2x1,b2y0,b2y1)) );
      end
  endfunction

  wire [11:0] pxb  = {oxc, 2'b00};
  wire [11:0] pyc  = {2'b00, oyc};
  wire        hit0 = F_in_box(pxb,         pyc);
  wire        hit1 = F_in_box(pxb + 12'd1, pyc);
  wire        hit2 = F_in_box(pxb + 12'd2, pyc);
  wire        hit3 = F_in_box(pxb + 12'd3, pyc);

  wire [95:0] S_box_pix = {
      hit0 ? box_col : S_out_pix[95:72],
      hit1 ? box_col : S_out_pix[71:48],
      hit2 ? box_col : S_out_pix[47:24],
      hit3 ? box_col : S_out_pix[23:0] };
  data_96bit_to_128bit u_data_96bit_to_128bit(
      .I_clk              ( axi4s_video_aclk  ),
      .I_rst_n            ( I_rst_n           ),
      .I_96b_frame_start  ( mux_O_tuser	    ),
      .I_96b_valid        ( mux_O_tvalid 		),
      .I_96b_data         ( S_box_pix 		),
      .O_128b_frame_start ( awb_O_tuser_128  	),
      .O_128b_valid       ( awb_O_tvalid_128 	),
      .O_128b_data        ( awb_O_tdata_128  	)
  );

  assign O_tdata  = awb_O_tdata_128;
  assign O_tvalid = awb_O_tvalid_128;
  assign O_tuser  = awb_O_tuser_128;
  assign O_tlast  = awb_O_tlast;

endmodule

module gray_96 (
    input               I_clk,
    input               I_rst_n,
    input      [95:0]   I_tdata,
    input               I_tvalid,
    input               I_tuser,
    input               I_tlast,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output reg          O_tuser,
    output reg          O_tlast
);

    function [7:0] F_gray;
        input [23:0] p;
        begin
            F_gray = {2'b0, p[23:18]} + {1'b0, p[15:9]} + {2'b0, p[7:2]};
        end
    endfunction

    wire [7:0] g0 = F_gray(I_tdata[95:72]);
    wire [7:0] g1 = F_gray(I_tdata[71:48]);
    wire [7:0] g2 = F_gray(I_tdata[47:24]);
    wire [7:0] g3 = F_gray(I_tdata[23:0]);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tdata  <= 96'd0;
            O_tvalid <= 1'b0;
            O_tuser  <= 1'b0;
            O_tlast  <= 1'b0;
        end else begin
            O_tvalid <= I_tvalid;
            O_tuser  <= I_tuser;
            O_tlast  <= I_tlast;
            O_tdata  <= I_tvalid ? {g0,g0,g0, g1,g1,g1, g2,g2,g2, g3,g3,g3} : 96'd0;
        end
    end

endmodule

module motion_box #(
    parameter [7:0]  DIFF_BRIGHT = 8'd8,
    parameter [7:0]  DIFF_DARK   = 8'd4,
    parameter [6:0]  DARK_Y      = 7'd60,
    parameter [3:0]  MIN_3X3     = 4'd5,
    parameter [15:0] ALARM_NUM   = 16'd1440,
    parameter [15:0] ALARM_AREA  = 16'd7200,
    parameter [8:0]  ALARM_HOLD  = 9'd60
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    input  wire        I_tuser,
    input  wire        I_tlast,

    output reg         O_box_en,
    output reg  [11:0] O_box_x0,
    output reg  [11:0] O_box_x1,
    output reg  [11:0] O_box_y0,
    output reg  [11:0] O_box_y1,
    output reg         O_alarm,
    output reg  [15:0] O_motion_cnt,
    output reg         O_b1_en,
    output reg  [11:0] O_b1_x0, O_b1_x1, O_b1_y0, O_b1_y1,
    output reg         O_b2_en,
    output reg  [11:0] O_b2_x0, O_b2_x1, O_b2_y0, O_b2_y1
);

    localparam FIXED_BOX = 1'b0;

    function [11:0] F_step;
        input [11:0] cur;
        input [11:0] tgt;
        reg [11:0] d;
        begin
            d = (cur > tgt) ? (cur - tgt) : (tgt - cur);
            F_step = (d <= 12'd16) ? cur : tgt;
        end
    endfunction

    reg  [8:0] xc;
    reg  [9:0] yc;

    wire        line_start = I_tvalid & (I_tlast | I_tuser);
    wire [8:0]  xc_cur     = line_start ? 9'd0 : xc;
    wire [9:0]  yc_cur     = I_tuser ? 10'd0 : (I_tlast ? (yc + 10'd1) : yc);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            xc <= 9'd1;
            yc <= 10'd0;
        end
        else if (I_tuser) begin
            xc <= 9'd1;
            yc <= 10'd0;
        end
        else if (I_tvalid) begin
            if (I_tlast) begin
                xc <= 9'd1;
                yc <= (yc_cur >= 10'd719) ? 10'd0 : yc_cur;
            end
            else begin
                xc <= xc + 9'd1;
            end
        end
    end

    function [7:0] F_y;
        input [23:0] p;
        begin
            F_y = ({2'b00, p[23:16]} + {p[15:8], 1'b0} + {2'b00, p[7:0]}) >> 2;
        end
    endfunction

    wire [7:0] y0 = F_y(I_tdata[95:72]);
    wire [7:0] y1 = F_y(I_tdata[71:48]);
    wire [7:0] y2 = F_y(I_tdata[47:24]);
    wire [7:0] y3 = F_y(I_tdata[23:0]);
    wire [9:0] s4 = y0 + y1 + y2 + y3;

    wire [7:0] bx       = xc_cur[8:1];
    wire [6:0] by       = yc_cur[9:3];
    wire       odd_beat = I_tvalid & xc_cur[0];

    wire       last_row = (yc_cur[2:0] == 3'd7);

    reg  [9:0] s4_q;
    always @(posedge I_clk) if (I_tvalid & ~xc_cur[0]) s4_q <= s4;

    wire [10:0] cellsum = s4_q + s4;
    reg  [13:0] acc [0:159];

    wire [13:0] acc_sum = acc[bx] + {3'b000, cellsum};
    wire        cell_done = odd_beat & last_row;
    wire [7:0]  ycell     = acc_sum[13:6];

    always @(posedge I_clk) begin
        if (odd_beat) acc[bx] <= last_row ? 14'd0 : acc_sum;
    end

    wire [13:0] fb_addr = {by, 7'd0} + {by, 5'd0} + bx;
    reg  [7:0]  prev_y;
    (* ram_style = "block" *) reg [7:0]  ybuf [0:14399];

    always @(posedge I_clk) begin
        if (cell_done) begin
            prev_y        <= ybuf[fb_addr];
            ybuf[fb_addr] <= ycell;
        end
    end

    reg        p_vld;
    reg  [7:0] p_y;
    reg  [6:0] p_bx;
    reg  [6:0] p_by;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin p_vld <= 1'b0; p_y <= 8'd0; p_bx <= 8'd0; p_by <= 7'd0; end
        else begin
            p_vld <= cell_done;
            p_y   <= ycell;
            p_bx  <= bx;
            p_by  <= by;
        end
    end

    (* ram_style = "block" *) reg [4:0] hbuf [0:14399];
    reg  [4:0] h_read;
    wire [13:0] p_addr = {p_by, 7'd0} + {p_by, 5'd0} + p_bx;

    always @(posedge I_clk) if (cell_done) h_read <= hbuf[fb_addr];

    reg [1:0] warm;
    wire      warm_ok = (warm == 2'd2);

    wire [8:0]  ysum9  = {1'b0, p_y} + {1'b0, prev_y};
    wire [7:0]  yavg   = ysum9[8:1];
    wire [7:0]  diff   = (p_y > prev_y) ? (p_y - prev_y) : (prev_y - p_y);
    wire        dark   = (yavg <= DARK_Y);
    wire [8:0]  dgain  = dark ? {diff, 1'b0} : {1'b0, diff};
    wire [8:0]  dfloor = dark ? {5'd0, DIFF_DARK} : {5'd0, DIFF_BRIGHT};
    wire [10:0] dg4    = {dgain, 2'b00};
    wire        raw2   = p_vld & warm_ok & (dgain > dfloor) & (dg4 > {2'b00, ysum9});

    wire [4:0] h_new = {h_read[3:0], raw2};
    wire [2:0] sum_5 = h_read[0] + h_read[1] + h_read[2] + h_read[3] + h_read[4];
    wire       raw   = (sum_5 >= 3'd2);

    always @(posedge I_clk) if (p_vld) hbuf[p_addr] <= h_new;

    reg [159:0] m0, m1, m2;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin m0 <= 160'd0; m1 <= 160'd0; m2 <= 160'd0; end
        else if (I_tuser) begin m0 <= 160'd0; m1 <= 160'd0; m2 <= 160'd0; end
        else if (p_vld) begin
            m0 <= {m0[158:0], raw};
            m1 <= {m1[158:0], m0[159]};
            m2 <= {m2[158:0], m1[159]};
        end
    end

    reg        v2;
    reg [7:0]  c_bx;
    reg [6:0]  c_by;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin v2 <= 1'b0; c_bx <= 8'd0; c_by <= 7'd0; end
        else begin v2 <= p_vld; c_bx <= p_bx; c_by <= p_by; end
    end

    wire [3:0] cnt9 = m0[0] + m0[1] + m0[2] +
                      m1[0] + m1[1] + m1[2] +
                      m2[0] + m2[1] + m2[2];
    wire       mvalid = v2 & (cnt9 >= MIN_3X3) & (c_bx >= 8'd2) & (c_by >= 7'd2);

    reg [15:0] cnt_frm;
    reg [7:0]  x_min, x_max;
    reg [6:0]  y_min, y_max;
    reg        frame_vld;
    reg [8:0]  hold;
    reg        trig_d;

    localparam [15:0] MIN_CELLS = 16'd6;
    reg [7:0]  t0x0,t0x1,t1x0,t1x1,t2x0,t2x1;
    reg [6:0]  t0y0,t0y1,t1y0,t1y1,t2y0,t2y1;
    reg [15:0] t0c,t1c,t2c;
    reg        t0a,t1a,t2a;

    wire       s01 = (t0x0 <= t1x0);
    wire [7:0] a_x0 = s01 ? t0x0 : t1x0;
    wire [7:0] b_x0 = s01 ? t1x0 : t0x0;
    wire [7:0] a_x1 = s01 ? t0x1 : t1x1;
    wire [7:0] b_x1 = s01 ? t1x1 : t0x1;
    wire [6:0] a_y0 = s01 ? t0y0 : t1y0;
    wire [6:0] b_y0 = s01 ? t1y0 : t0y0;
    wire [6:0] a_y1 = s01 ? t0y1 : t1y1;
    wire [6:0] b_y1 = s01 ? t1y1 : t0y1;
    wire [15:0] a_c = s01 ? t0c : t1c;
    wire [15:0] b_c = s01 ? t1c : t0c;
    wire       sB2 = (b_x0 <= t2x0);
    wire [7:0] c_x0 = sB2 ? b_x0 : t2x0;
    wire [7:0] h_x0 = sB2 ? t2x0 : b_x0;
    wire [7:0] c_x1 = sB2 ? b_x1 : t2x1;
    wire [7:0] h_x1 = sB2 ? t2x1 : b_x1;
    wire [6:0] c_y0 = sB2 ? b_y0 : t2y0;
    wire [6:0] h_y0 = sB2 ? t2y0 : b_y0;
    wire [6:0] c_y1 = sB2 ? b_y1 : t2y1;
    wire [6:0] h_y1 = sB2 ? t2y1 : b_y1;
    wire [15:0] c_c = sB2 ? b_c : t2c;
    wire [15:0] h_c = sB2 ? t2c : b_c;
    wire       sAC = (a_x0 <= c_x0);
    wire [7:0] f_x0 = sAC ? a_x0 : c_x0;
    wire [7:0] g_x0 = sAC ? c_x0 : a_x0;

    wire [7:0] f_x1 = sAC ? a_x1 : c_x1;
    wire [7:0] g_x1 = sAC ? c_x1 : a_x1;
    wire [6:0] f_y0 = sAC ? a_y0 : c_y0;
    wire [6:0] g_y0 = sAC ? c_y0 : a_y0;
    wire [6:0] f_y1 = sAC ? a_y1 : c_y1;
    wire [6:0] g_y1 = sAC ? c_y1 : a_y1;
    wire [15:0] f_c = sAC ? a_c : c_c;
    wire [15:0] g_c = sAC ? c_c : a_c;

    wire [8:0] f_w = {1'b0,f_x1} - {1'b0,f_x0} + 9'd1;
    wire [8:0] f_h = {2'b00,f_y1} - {2'b00,f_y0} + 9'd1;
    wire [8:0] g_w = {1'b0,g_x1} - {1'b0,g_x0} + 9'd1;
    wire [8:0] g_h = {2'b00,g_y1} - {2'b00,g_y0} + 9'd1;
    wire [8:0] h_w = {1'b0,h_x1} - {1'b0,h_x0} + 9'd1;
    wire [8:0] h_h = {2'b00,h_y1} - {2'b00,h_y0} + 9'd1;
    wire f_big = (f_w >= 9'd8) && (f_h >= 9'd8);
    wire g_big = (g_w >= 9'd8) && (g_h >= 9'd8);
    wire h_big = (h_w >= 9'd8) && (h_h >= 9'd8);

    wire       valid_edge = (c_bx >= 8'd1) && (c_bx <= 8'd158) && (c_by >= 7'd1) && (c_by <= 7'd88);

    reg [7:0]  sx0, sx1;
    reg [6:0]  sy0, sy1;


    wire [7:0] cx = c_bx - 8'd1;
    wire [6:0] cy = c_by - 7'd1;

    wire t0hit = t0a && (cx + 8'd16 >= t0x0) && (cx <= t0x1 + 8'd16) && ({1'b0,cy} + 8'd16 >= {1'b0,t0y0}) && ({1'b0,cy} <= {1'b0,t0y1} + 8'd16);
    wire t1hit = t1a && (cx + 8'd16 >= t1x0) && (cx <= t1x1 + 8'd16) && ({1'b0,cy} + 8'd16 >= {1'b0,t1y0}) && ({1'b0,cy} <= {1'b0,t1y1} + 8'd16);
    wire t2hit = t2a && (cx + 8'd16 >= t2x0) && (cx <= t2x1 + 8'd16) && ({1'b0,cy} + 8'd16 >= {1'b0,t2y0}) && ({1'b0,cy} <= {1'b0,t2y1} + 8'd16);


    wire [8:0] f_w9 = {1'b0, f_x1} - {1'b0, f_x0} + 9'd1;
    wire [8:0] f_h9 = {2'b00, f_y1} - {2'b00, f_y0} + 9'd1;
    wire [17:0] f_area = f_w9 * f_h9;
    wire       trig = (f_c >= MIN_CELLS) && f_big && (f_area >= ALARM_AREA);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            cnt_frm   <= 16'd0;
            x_min     <= 8'd159;  x_max <= 8'd0;
            y_min     <= 7'd89;   y_max <= 7'd0;
            frame_vld <= 1'b0;
            warm      <= 2'd0;
            hold      <= 9'd0;
            trig_d    <= 1'b0;
            O_box_en  <= 1'b0;
            O_box_x0  <= 12'd0; O_box_x1 <= 12'd0;
            sx0 <= 8'd0; sx1 <= 8'd0; sy0 <= 7'd0; sy1 <= 7'd0;
            O_box_y0  <= 12'd0; O_box_y1 <= 12'd0;
            O_alarm   <= 1'b0;
            O_motion_cnt <= 16'd0;
        end
        else if (I_tuser) begin

            cnt_frm   <= (mvalid ? 16'd1 : 16'd0);
            x_min     <= mvalid ? cx : 8'd159;
            x_max     <= mvalid ? cx : 8'd0;
            y_min     <= mvalid ? cy : 7'd89;
            y_max     <= mvalid ? cy : 7'd0;
            frame_vld <= 1'b1;

            trig_d <= trig;
            if (trig & ~trig_d) hold <= ALARM_HOLD;
            else if (hold != 9'd0) hold <= hold - 9'd1;

            if (warm != 2'd2) begin
                warm     <= warm + 2'd1;
                O_box_en <= 1'b0;
                O_alarm  <= 1'b0;
            end
            else begin
                O_motion_cnt <= cnt_frm;
                O_alarm      <= (hold != 9'd0);

                if ((f_c >= MIN_CELLS) && f_big) begin
                    O_box_en <= 1'b1;
                    if (!O_box_en) begin
                        O_box_x0 <= {f_x0,3'b000}; O_box_x1 <= {f_x1,3'b000} + 12'd7;
                        O_box_y0 <= {f_y0,3'b000}; O_box_y1 <= {f_y1,3'b000} + 12'd7;
                    end else begin
                        O_box_x0 <= F_step(O_box_x0, {f_x0,3'b000});
                        O_box_x1 <= F_step(O_box_x1, {f_x1,3'b000} + 12'd7);
                        O_box_y0 <= F_step(O_box_y0, {f_y0,3'b000});
                        O_box_y1 <= F_step(O_box_y1, {f_y1,3'b000} + 12'd7);
                    end
                end else O_box_en <= 1'b0;

                if ((g_c >= MIN_CELLS) && g_big) begin
                    O_b1_en <= 1'b1;
                    if (!O_b1_en) begin
                        O_b1_x0 <= {g_x0,3'b000}; O_b1_x1 <= {g_x1,3'b000} + 12'd7;
                        O_b1_y0 <= {g_y0,3'b000}; O_b1_y1 <= {g_y1,3'b000} + 12'd7;
                    end else begin
                        O_b1_x0 <= F_step(O_b1_x0, {g_x0,3'b000});
                        O_b1_x1 <= F_step(O_b1_x1, {g_x1,3'b000} + 12'd7);
                        O_b1_y0 <= F_step(O_b1_y0, {g_y0,3'b000});
                        O_b1_y1 <= F_step(O_b1_y1, {g_y1,3'b000} + 12'd7);
                    end
                end else O_b1_en <= 1'b0;

                if ((h_c >= MIN_CELLS) && h_big) begin
                    O_b2_en <= 1'b1;
                    if (!O_b2_en) begin
                        O_b2_x0 <= {h_x0,3'b000}; O_b2_x1 <= {h_x1,3'b000} + 12'd7;
                        O_b2_y0 <= {h_y0,3'b000}; O_b2_y1 <= {h_y1,3'b000} + 12'd7;
                    end else begin
                        O_b2_x0 <= F_step(O_b2_x0, {h_x0,3'b000});
                        O_b2_x1 <= F_step(O_b2_x1, {h_x1,3'b000} + 12'd7);
                        O_b2_y0 <= F_step(O_b2_y0, {h_y0,3'b000});
                        O_b2_y1 <= F_step(O_b2_y1, {h_y1,3'b000} + 12'd7);
                    end
                end else O_b2_en <= 1'b0;

                t0a <= 1'b0; t1a <= 1'b0; t2a <= 1'b0;
                t0c <= 16'd0; t1c <= 16'd0; t2c <= 16'd0;
        end
            end
        else if (mvalid) begin

            cnt_frm <= cnt_frm + 16'd1;
            if (t0hit) begin
                if (cx < t0x0) t0x0 <= cx;
                if (cx > t0x1) t0x1 <= cx;
                if (cy < t0y0) t0y0 <= cy;
                if (cy > t0y1) t0y1 <= cy;
                t0c <= t0c + 16'd1;
            end else if (t1hit) begin
                if (cx < t1x0) t1x0 <= cx;
                if (cx > t1x1) t1x1 <= cx;
                if (cy < t1y0) t1y0 <= cy;
                if (cy > t1y1) t1y1 <= cy;
                t1c <= t1c + 16'd1;
            end else if (t2hit) begin
                if (cx < t2x0) t2x0 <= cx;
                if (cx > t2x1) t2x1 <= cx;
                if (cy < t2y0) t2y0 <= cy;
                if (cy > t2y1) t2y1 <= cy;
                t2c <= t2c + 16'd1;
            end else if (!t0a) begin
                t0a<=1'b1; t0x0<=cx; t0x1<=cx; t0y0<=cy; t0y1<=cy; t0c<=16'd1;
            end else if (!t1a) begin
                t1a<=1'b1; t1x0<=cx; t1x1<=cx; t1y0<=cy; t1y1<=cy; t1c<=16'd1;
            end else if (!t2a) begin
                t2a<=1'b1; t2x0<=cx; t2x1<=cx; t2y0<=cy; t2y1<=cy; t2c<=16'd1;
            end
            if (valid_edge) begin
                if (cx < x_min) x_min <= cx;
                if (cx > x_max) x_max <= cx;
                if (cy < y_min) y_min <= cy;
                if (cy > y_max) y_max <= cy;
            end
    end
    end

endmodule

`timescale 1ns / 1ps

module isp_raw_pre #(

    parameter [9:0]  BLACK_LEVEL_DEF = 10'd16  ,
    parameter [7:0]  GAIN_NUM_DEF    = 8'd17   ,
    parameter [3:0]  SHIFT_BITS      = 4'd6
)(
    input  wire         I_clk       ,
    input  wire         I_rst_n     ,

    input  wire [39:0]  I_tdata     ,
    input  wire         I_tvalid    ,
    input  wire         I_tuser     ,
    input  wire         I_tlast     ,
    output wire         I_tready    ,

    input  wire [9:0]   I_black_level,
    input  wire [7:0]   I_gain_num   ,

    output wire [39:0]  O_tdata     ,
    output wire         O_tvalid    ,
    output wire         O_tuser     ,
    output wire         O_tlast     ,
    input  wire         O_tready
);

    wire [11:0] S_bl = {I_black_level, 2'b00};

    wire [9:0] S_pix_in [0:3];
    assign S_pix_in[0] = I_tdata[39:30];
    assign S_pix_in[1] = I_tdata[29:20];
    assign S_pix_in[2] = I_tdata[19:10];
    assign S_pix_in[3] = I_tdata[ 9: 0];

    wire [9:0] S_blc    [0:3];
    wire [18:0] S_mul   [0:3];
    wire [18:0] S_round [0:3];
    wire [18:0] S_shift [0:3];
    wire [ 7:0] S_val   [0:3];

    wire [39:0] O_tdata_r;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : G_PIX

            assign S_blc[i] = (S_pix_in[i] > S_bl[9:0]) ? (S_pix_in[i] - S_bl[9:0])
                                                        : 10'd0;

            assign S_mul[i] = {S_blc[i], 4'b0000} + {9'd0, S_blc[i]};

            assign S_round[i] = S_mul[i] + {{(18-SHIFT_BITS){1'b0}}, 1'b1, {(SHIFT_BITS-1){1'b0}}};
            assign S_shift[i] = S_round[i] >> SHIFT_BITS;

            assign S_val[i] = (|S_shift[i][18:8]) ? 8'd255 : S_shift[i][7:0];

            assign O_tdata_r[(39 - 8*i) -: 8] = S_val[i];

        end
    endgenerate

    reg [7:0] S_val_r0 [0:3];
    reg [7:0] S_val_r1 [0:3];

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_val_r0[0] <= 8'd0;  S_val_r0[1] <= 8'd0;
            S_val_r0[2] <= 8'd0;  S_val_r0[3] <= 8'd0;
            S_val_r1[0] <= 8'd0;  S_val_r1[1] <= 8'd0;
            S_val_r1[2] <= 8'd0;  S_val_r1[3] <= 8'd0;
        end else begin
            S_val_r0[0] <= S_val[0];  S_val_r0[1] <= S_val[1];
            S_val_r0[2] <= S_val[2];  S_val_r0[3] <= S_val[3];
            S_val_r1[0] <= S_val_r0[0];  S_val_r1[1] <= S_val_r0[1];
            S_val_r1[2] <= S_val_r0[2];  S_val_r1[3] <= S_val_r0[3];
        end
    end

    assign O_tdata = { S_val_r1[0], 2'b00,
                       S_val_r1[1], 2'b00,
                       S_val_r1[2], 2'b00,
                       S_val_r1[3], 2'b00 };

    reg [2:0] S_sync_r0, S_sync_r1;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_sync_r0 <= 3'b0;
            S_sync_r1 <= 3'b0;
        end else begin
            S_sync_r0 <= {I_tlast, I_tuser, I_tvalid};
            S_sync_r1 <= S_sync_r0;
        end
    end

    assign O_tvalid = S_sync_r1[0];
    assign O_tuser  = S_sync_r1[1];
    assign O_tlast  = S_sync_r1[2];

    assign I_tready = O_tready;

endmodule

`timescale 1ns / 1ps

module isp_gamma #(
    parameter [1:0] GAMMA_IDX_DEF = 2'd0
)(
    input  wire        I_clk   ,
    input  wire        I_rst_n ,
    input  wire [95:0] I_tdata ,
    input  wire        I_tvalid,
    input  wire        I_tuser ,
    input  wire        I_tlast ,
    output wire        I_tready,
    input  wire [1:0]  I_gamma_idx,
    output reg  [95:0] O_tdata ,
    output reg         O_tvalid,
    output reg         O_tuser ,
    output reg         O_tlast ,
    input  wire        O_tready
);

    wire [7:0] p0r = I_tdata[23:16], p0g = I_tdata[15:8], p0b = I_tdata[ 7:0];
    wire [7:0] p1r = I_tdata[47:40], p1g = I_tdata[39:32], p1b = I_tdata[31:24];
    wire [7:0] p2r = I_tdata[71:64], p2g = I_tdata[63:56], p2b = I_tdata[55:48];
    wire [7:0] p3r = I_tdata[95:88], p3g = I_tdata[87:80], p3b = I_tdata[79:72];

    wire [7:0] g0r;
    gamma_rom u_g0r (.I_clk(I_clk), .I_addr(p0r), .O_dout(g0r));
    wire [7:0] g0g;
    gamma_rom u_g0g (.I_clk(I_clk), .I_addr(p0g), .O_dout(g0g));
    wire [7:0] g0b;
    gamma_rom u_g0b (.I_clk(I_clk), .I_addr(p0b), .O_dout(g0b));
    wire [7:0] g1r;
    gamma_rom u_g1r (.I_clk(I_clk), .I_addr(p1r), .O_dout(g1r));
    wire [7:0] g1g;
    gamma_rom u_g1g (.I_clk(I_clk), .I_addr(p1g), .O_dout(g1g));
    wire [7:0] g1b;
    gamma_rom u_g1b (.I_clk(I_clk), .I_addr(p1b), .O_dout(g1b));
    wire [7:0] g2r;
    gamma_rom u_g2r (.I_clk(I_clk), .I_addr(p2r), .O_dout(g2r));
    wire [7:0] g2g;
    gamma_rom u_g2g (.I_clk(I_clk), .I_addr(p2g), .O_dout(g2g));
    wire [7:0] g2b;
    gamma_rom u_g2b (.I_clk(I_clk), .I_addr(p2b), .O_dout(g2b));
    wire [7:0] g3r;
    gamma_rom u_g3r (.I_clk(I_clk), .I_addr(p3r), .O_dout(g3r));
    wire [7:0] g3g;
    gamma_rom u_g3g (.I_clk(I_clk), .I_addr(p3g), .O_dout(g3g));
    wire [7:0] g3b;
    gamma_rom u_g3b (.I_clk(I_clk), .I_addr(p3b), .O_dout(g3b));

    always @(*) begin
        O_tdata = { g3r, g3g, g3b, g2r, g2g, g2b,
                    g1r, g1g, g1b, g0r, g0g, g0b };
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tvalid <= 1'b0;
            O_tuser  <= 1'b0;
            O_tlast  <= 1'b0;
        end else begin
            O_tvalid <= I_tvalid;
            O_tuser  <= I_tuser;
            O_tlast  <= I_tlast;
        end
    end

    assign I_tready = O_tready;

endmodule

module gamma_rom (
    input  wire       I_clk,
    input  wire [7:0] I_addr,
    output reg  [7:0] O_dout
);
    (* ram_style = "bram" *) reg [7:0] mem [0:255];

    initial begin
        mem[0] = 8'd0; mem[1] = 8'd0; mem[2] = 8'd0; mem[3] = 8'd0; mem[4] = 8'd3; mem[5] = 8'd6; mem[6] = 8'd8; mem[7] = 8'd11;
        mem[8] = 8'd13; mem[9] = 8'd15; mem[10] = 8'd17; mem[11] = 8'd19; mem[12] = 8'd23; mem[13] = 8'd25; mem[14] = 8'd27; mem[15] = 8'd29;
        mem[16] = 8'd32; mem[17] = 8'd34; mem[18] = 8'd36; mem[19] = 8'd38; mem[20] = 8'd40; mem[21] = 8'd42; mem[22] = 8'd44; mem[23] = 8'd46;
        mem[24] = 8'd48; mem[25] = 8'd49; mem[26] = 8'd51; mem[27] = 8'd52; mem[28] = 8'd54; mem[29] = 8'd55; mem[30] = 8'd57; mem[31] = 8'd58;
        mem[32] = 8'd62; mem[33] = 8'd63; mem[34] = 8'd65; mem[35] = 8'd66; mem[36] = 8'd68; mem[37] = 8'd69; mem[38] = 8'd71; mem[39] = 8'd72;
        mem[40] = 8'd74; mem[41] = 8'd75; mem[42] = 8'd77; mem[43] = 8'd78; mem[44] = 8'd80; mem[45] = 8'd81; mem[46] = 8'd83; mem[47] = 8'd84;
        mem[48] = 8'd89; mem[49] = 8'd90; mem[50] = 8'd92; mem[51] = 8'd93; mem[52] = 8'd95; mem[53] = 8'd96; mem[54] = 8'd98; mem[55] = 8'd99;
        mem[56] = 8'd101; mem[57] = 8'd102; mem[58] = 8'd104; mem[59] = 8'd105; mem[60] = 8'd107; mem[61] = 8'd108; mem[62] = 8'd110; mem[63] = 8'd111;
        mem[64] = 8'd112; mem[65] = 8'd113; mem[66] = 8'd114; mem[67] = 8'd115; mem[68] = 8'd116; mem[69] = 8'd117; mem[70] = 8'd118; mem[71] = 8'd119;
        mem[72] = 8'd120; mem[73] = 8'd121; mem[74] = 8'd122; mem[75] = 8'd123; mem[76] = 8'd124; mem[77] = 8'd125; mem[78] = 8'd126; mem[79] = 8'd127;
        mem[80] = 8'd128; mem[81] = 8'd129; mem[82] = 8'd130; mem[83] = 8'd131; mem[84] = 8'd132; mem[85] = 8'd133; mem[86] = 8'd134; mem[87] = 8'd135;
        mem[88] = 8'd136; mem[89] = 8'd137; mem[90] = 8'd138; mem[91] = 8'd139; mem[92] = 8'd140; mem[93] = 8'd141; mem[94] = 8'd142; mem[95] = 8'd143;
        mem[96] = 8'd151; mem[97] = 8'd152; mem[98] = 8'd153; mem[99] = 8'd154; mem[100] = 8'd155; mem[101] = 8'd156; mem[102] = 8'd157; mem[103] = 8'd158;
        mem[104] = 8'd159; mem[105] = 8'd160; mem[106] = 8'd161; mem[107] = 8'd162; mem[108] = 8'd163; mem[109] = 8'd164; mem[110] = 8'd165; mem[111] = 8'd166;
        mem[112] = 8'd167; mem[113] = 8'd168; mem[114] = 8'd169; mem[115] = 8'd170; mem[116] = 8'd171; mem[117] = 8'd172; mem[118] = 8'd173; mem[119] = 8'd174;
        mem[120] = 8'd175; mem[121] = 8'd176; mem[122] = 8'd177; mem[123] = 8'd178; mem[124] = 8'd179; mem[125] = 8'd180; mem[126] = 8'd181; mem[127] = 8'd182;
        mem[128] = 8'd183; mem[129] = 8'd184; mem[130] = 8'd185; mem[131] = 8'd186; mem[132] = 8'd186; mem[133] = 8'd187; mem[134] = 8'd188; mem[135] = 8'd189;
        mem[136] = 8'd189; mem[137] = 8'd190; mem[138] = 8'd191; mem[139] = 8'd192; mem[140] = 8'd192; mem[141] = 8'd193; mem[142] = 8'd194; mem[143] = 8'd195;
        mem[144] = 8'd195; mem[145] = 8'd196; mem[146] = 8'd197; mem[147] = 8'd198; mem[148] = 8'd198; mem[149] = 8'd199; mem[150] = 8'd200; mem[151] = 8'd201;
        mem[152] = 8'd201; mem[153] = 8'd202; mem[154] = 8'd203; mem[155] = 8'd204; mem[156] = 8'd204; mem[157] = 8'd205; mem[158] = 8'd206; mem[159] = 8'd207;
        mem[160] = 8'd207; mem[161] = 8'd208; mem[162] = 8'd209; mem[163] = 8'd210; mem[164] = 8'd210; mem[165] = 8'd211; mem[166] = 8'd212; mem[167] = 8'd213;
        mem[168] = 8'd213; mem[169] = 8'd214; mem[170] = 8'd215; mem[171] = 8'd216; mem[172] = 8'd216; mem[173] = 8'd217; mem[174] = 8'd218; mem[175] = 8'd219;
        mem[176] = 8'd219; mem[177] = 8'd220; mem[178] = 8'd221; mem[179] = 8'd222; mem[180] = 8'd222; mem[181] = 8'd223; mem[182] = 8'd224; mem[183] = 8'd225;
        mem[184] = 8'd225; mem[185] = 8'd226; mem[186] = 8'd227; mem[187] = 8'd228; mem[188] = 8'd228; mem[189] = 8'd228; mem[190] = 8'd228; mem[191] = 8'd228;
        mem[192] = 8'd228; mem[193] = 8'd228; mem[194] = 8'd229; mem[195] = 8'd229; mem[196] = 8'd230; mem[197] = 8'd230; mem[198] = 8'd231; mem[199] = 8'd231;
        mem[200] = 8'd232; mem[201] = 8'd232; mem[202] = 8'd233; mem[203] = 8'd233; mem[204] = 8'd234; mem[205] = 8'd234; mem[206] = 8'd235; mem[207] = 8'd235;
        mem[208] = 8'd236; mem[209] = 8'd236; mem[210] = 8'd237; mem[211] = 8'd237; mem[212] = 8'd238; mem[213] = 8'd238; mem[214] = 8'd239; mem[215] = 8'd239;
        mem[216] = 8'd240; mem[217] = 8'd240; mem[218] = 8'd241; mem[219] = 8'd241; mem[220] = 8'd242; mem[221] = 8'd242; mem[222] = 8'd243; mem[223] = 8'd243;
        mem[224] = 8'd244; mem[225] = 8'd244; mem[226] = 8'd245; mem[227] = 8'd245; mem[228] = 8'd246; mem[229] = 8'd246; mem[230] = 8'd247; mem[231] = 8'd247;
        mem[232] = 8'd248; mem[233] = 8'd248; mem[234] = 8'd249; mem[235] = 8'd249; mem[236] = 8'd250; mem[237] = 8'd250; mem[238] = 8'd251; mem[239] = 8'd251;
        mem[240] = 8'd252; mem[241] = 8'd252; mem[242] = 8'd253; mem[243] = 8'd253; mem[244] = 8'd254; mem[245] = 8'd254; mem[246] = 8'd255; mem[247] = 8'd255;
        mem[248] = 8'd255; mem[249] = 8'd255; mem[250] = 8'd255; mem[251] = 8'd255; mem[252] = 8'd255; mem[253] = 8'd255; mem[254] = 8'd255; mem[255] = 8'd255;
    end

    always @(posedge I_clk) O_dout <= mem[I_addr];

endmodule

`timescale 1ns / 1ps

`define M_N26(d) (-(((d))<<4) - (((d))<<3) - (((d))<<1))
`define M_N31(d) (-(((d))<<4) - (((d))<<3) - (((d))<<2) - (((d))<<1) - ((d)))
`define M_N20(d) (-(((d))<<4) - (((d))<<2))
`define M_N13(d) (-(((d))<<3) - (((d))<<2) - ((d)))
`define M_N8(d)  (-(((d))<<3))
`define M_N5(d)  (-(((d))<<2) - ((d)))

module isp_ccm #(
    parameter [2:0] SAT_IDX_DEF = 3'd2,
    parameter [2:0] WB_R_DEF    = 3'd0,
    parameter [2:0] WB_B_DEF    = 3'd0,
    parameter       CCM_PRESET  = 0
)(
    input  wire        I_clk   ,
    input  wire        I_rst_n ,

    input  wire [95:0] I_tdata ,
    input  wire        I_tvalid,
    input  wire        I_tuser ,
    input  wire        I_tlast ,
    output wire        I_tready,

    input  wire [2:0]  I_sat_idx,
    input  wire [2:0]  I_wb_r_sel,

    input  wire [2:0]  I_wb_g_sel,
    input  wire [2:0]  I_wb_b_sel,

    output reg  [95:0] O_tdata ,
    output reg         O_tvalid,
    output reg         O_tuser ,
    output reg         O_tlast ,
    input  wire        O_tready
);

    function signed [8:0] coef;
        input [2:0] k;
        begin
            if (CCM_PRESET == 0) begin

                case (k)
                    3'd0: coef = -9'sd26;
                    3'd1: coef =  9'sd0;
                    3'd2: coef = -9'sd13;
                    3'd3: coef = -9'sd13;
                    3'd4: coef =  9'sd0;
                    default: coef = -9'sd31;
                endcase
            end else begin

                case (k)
                    3'd0: coef = -9'sd31;
                    3'd1: coef = -9'sd8;
                    3'd2: coef = -9'sd20;
                    3'd3: coef = -9'sd20;
                    3'd4: coef = -9'sd5;
                    default: coef = -9'sd26;
                endcase
            end
        end
    endfunction

    function [11:0] wb_gain;
        input [2:0] sel;
        begin
            case (sel)
                3'd0: wb_gain = 12'd1229;
                3'd1: wb_gain = 12'd1434;
                3'd2: wb_gain = 12'd1638;
                3'd3: wb_gain = 12'd1843;
                3'd4: wb_gain = 12'd2048;
                3'd5: wb_gain = 12'd2355;
                3'd6: wb_gain = 12'd2662;
                default: wb_gain = 12'd3072;
            endcase
        end
    endfunction

    function [7:0] ccm_fin;
        input [7:0]         v;
        input signed [14:0] acc;

        reg   signed [15:0] t;
        begin
            t = (acc + 15'sd128) >>> 8;
            t = $signed({8'b0, v}) + t;
            if (t > 16'sd255)      ccm_fin = 8'd255;
            else if (t < 16'sd0)   ccm_fin = 8'd0;
            else                   ccm_fin = t[7:0];
        end
    endfunction

    wire [7:0] p0r = I_tdata[23:16], p0g = I_tdata[15:8], p0b = I_tdata[ 7:0];
    wire [7:0] p1r = I_tdata[47:40], p1g = I_tdata[39:32], p1b = I_tdata[31:24];
    wire [7:0] p2r = I_tdata[71:64], p2g = I_tdata[63:56], p2b = I_tdata[55:48];
    wire [7:0] p3r = I_tdata[95:88], p3g = I_tdata[87:80], p3b = I_tdata[79:72];

    wire signed [9:0] d0_rg = $signed({2'b0,p0r}) - $signed({2'b0,p0g});
    wire signed [9:0] d0_rb = $signed({2'b0,p0r}) - $signed({2'b0,p0b});
    wire signed [9:0] d0_bg = $signed({2'b0,p0b}) - $signed({2'b0,p0g});

    wire signed [9:0] d1_rg = $signed({2'b0,p1r}) - $signed({2'b0,p1g});
    wire signed [9:0] d1_rb = $signed({2'b0,p1r}) - $signed({2'b0,p1b});
    wire signed [9:0] d1_bg = $signed({2'b0,p1b}) - $signed({2'b0,p1g});

    wire signed [9:0] d2_rg = $signed({2'b0,p2r}) - $signed({2'b0,p2g});
    wire signed [9:0] d2_rb = $signed({2'b0,p2r}) - $signed({2'b0,p2b});
    wire signed [9:0] d2_bg = $signed({2'b0,p2b}) - $signed({2'b0,p2g});

    wire signed [9:0] d3_rg = $signed({2'b0,p3r}) - $signed({2'b0,p3g});
    wire signed [9:0] d3_rb = $signed({2'b0,p3r}) - $signed({2'b0,p3b});
    wire signed [9:0] d3_bg = $signed({2'b0,p3b}) - $signed({2'b0,p3g});

    wire signed [14:0] x0_rg = {{5{d0_rg[9]}}, d0_rg};
    wire signed [14:0] x0_rb = {{5{d0_rb[9]}}, d0_rb};
    wire signed [14:0] x0_bg = {{5{d0_bg[9]}}, d0_bg};
    wire signed [14:0] x0_g  = x0_rg + x0_bg;

    wire signed [14:0] x1_rg = {{5{d1_rg[9]}}, d1_rg};
    wire signed [14:0] x1_rb = {{5{d1_rb[9]}}, d1_rb};
    wire signed [14:0] x1_bg = {{5{d1_bg[9]}}, d1_bg};
    wire signed [14:0] x1_g  = x1_rg + x1_bg;

    wire signed [14:0] x2_rg = {{5{d2_rg[9]}}, d2_rg};
    wire signed [14:0] x2_rb = {{5{d2_rb[9]}}, d2_rb};
    wire signed [14:0] x2_bg = {{5{d2_bg[9]}}, d2_bg};
    wire signed [14:0] x2_g  = x2_rg + x2_bg;

    wire signed [14:0] x3_rg = {{5{d3_rg[9]}}, d3_rg};
    wire signed [14:0] x3_rb = {{5{d3_rb[9]}}, d3_rb};
    wire signed [14:0] x3_bg = {{5{d3_bg[9]}}, d3_bg};
    wire signed [14:0] x3_g  = x3_rg + x3_bg;

    function [14:0] m26; input signed [14:0] d; begin m26 = (d<<4) + (d<<3) + (d<<1); end endfunction
    function [14:0] m31; input signed [14:0] d; begin m31 = (d<<5) - d; end endfunction
    function [14:0] m13; input signed [14:0] d; begin m13 = (d<<3) + (d<<2) + d; end endfunction
    function [14:0] m20; input signed [14:0] d; begin m20 = (d<<4) + (d<<2); end endfunction
    function [14:0] m8;  input signed [14:0] d; begin m8  = (d<<3); end endfunction
    function [14:0] m5;  input signed [14:0] d; begin m5  = (d<<2) + d; end endfunction

    wire signed [14:0] a0r, a0g, a0b, a1r, a1g, a1b;
    wire signed [14:0] a2r, a2g, a2b, a3r, a3g, a3b;

    generate
      if (CCM_PRESET == 0) begin : G_CCM_IN

          assign a0r = m26(x0_rg);
          assign a0g = -m13(x0_g);
          assign a0b = m31(x0_bg);
          assign a1r = m26(x1_rg);
          assign a1g = -m13(x1_g);
          assign a1b = m31(x1_bg);
          assign a2r = m26(x2_rg);
          assign a2g = -m13(x2_g);
          assign a2b = m31(x2_bg);
          assign a3r = m26(x3_rg);
          assign a3g = -m13(x3_g);
          assign a3b = m31(x3_bg);
      end else begin : G_CCM_OUT

          assign a0r = m31(x0_rg) + m8(x0_rb);
          assign a0g = -m20(x0_g);
          assign a0b = -m5(x0_rb) + m26(x0_bg);
          assign a1r = m31(x1_rg) + m8(x1_rb);
          assign a1g = -m20(x1_g);
          assign a1b = -m5(x1_rb) + m26(x1_bg);
          assign a2r = m31(x2_rg) + m8(x2_rb);
          assign a2g = -m20(x2_g);
          assign a2b = -m5(x2_rb) + m26(x2_bg);
          assign a3r = m31(x3_rg) + m8(x3_rb);
          assign a3g = -m20(x3_g);
          assign a3b = -m5(x3_rb) + m26(x3_bg);
      end
    endgenerate

    wire [7:0] q0r = ccm_fin(p0r, a0r);
    wire [7:0] q0g = ccm_fin(p0g, a0g);
    wire [7:0] q0b = ccm_fin(p0b, a0b);

    wire [7:0] q1r = ccm_fin(p1r, a1r);
    wire [7:0] q1g = ccm_fin(p1g, a1g);
    wire [7:0] q1b = ccm_fin(p1b, a1b);

    wire [7:0] q2r = ccm_fin(p2r, a2r);
    wire [7:0] q2g = ccm_fin(p2g, a2g);
    wire [7:0] q2b = ccm_fin(p2b, a2b);

    wire [7:0] q3r = ccm_fin(p3r, a3r);
    wire [7:0] q3g = ccm_fin(p3g, a3g);
    wire [7:0] q3b = ccm_fin(p3b, a3b);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tdata  <= 96'd0;
            O_tvalid <= 1'b0;
            O_tuser  <= 1'b0;
            O_tlast  <= 1'b0;
        end else begin
            O_tvalid <= I_tvalid;
            O_tuser  <= I_tuser;
            O_tlast  <= I_tlast;
            if (I_tvalid) begin
                O_tdata <= { q3r, q3g, q3b,
                             q2r, q2g, q2b,
                             q1r, q1g, q1b,
                             q0r, q0g, q0b };
            end
        end
    end

    assign I_tready = O_tready;

endmodule

`undef M_N26
`undef M_N31
`undef M_N20
`undef M_N13
`undef M_N8
`undef M_N5


module blur3_h (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    input  wire        I_tuser,
    input  wire        I_tlast,
    output reg  [95:0] O_tdata,
    output reg         O_tvalid,
    output reg         O_tuser,
    output reg         O_tlast
);

    function [7:0] avg3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        reg [9:0]  s;
        reg [15:0] t;
        begin
            s = {2'b00,a} + {2'b00,b} + {2'b00,c};
            t = (s << 6) + (s << 4) + (s << 2) + s;
            avg3 = t[15:8];
        end
    endfunction

    reg [95:0] d;
    reg [95:0] pd;
    reg        v1, u1, l1;

    wire [23:0] d0 = d[95:72], d1 = d[71:48], d2 = d[47:24], d3 = d[23:0];
    wire [7:0]  left3 = pd[7:0];
    wire [23:0] cur0  = I_tdata[95:72];

    wire [7:0] r0 = avg3(left3,      d0[23:16], d1[23:16]);
    wire [7:0] g0 = avg3(pd[15:8],   d0[15:8],  d1[15:8]);
    wire [7:0] b0 = avg3(pd[7:0],    d0[7:0],   d1[7:0]);
    wire [7:0] r1 = avg3(d0[23:16],  d1[23:16], d2[23:16]);
    wire [7:0] g1 = avg3(d0[15:8],   d1[15:8],  d2[15:8]);
    wire [7:0] b1 = avg3(d0[7:0],    d1[7:0],   d2[7:0]);
    wire [7:0] r2 = avg3(d1[23:16],  d2[23:16], d3[23:16]);
    wire [7:0] g2 = avg3(d1[15:8],   d2[15:8],  d3[15:8]);
    wire [7:0] b2 = avg3(d1[7:0],    d2[7:0],   d3[7:0]);
    wire [7:0] r3 = avg3(d2[23:16],  d3[23:16], cur0[23:16]);
    wire [7:0] g3 = avg3(d2[15:8],   d3[15:8],  cur0[15:8]);
    wire [7:0] b3 = avg3(d2[7:0],    d3[7:0],   cur0[7:0]);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            d <= 96'd0; pd <= 96'd0; v1 <= 1'b0; u1 <= 1'b0; l1 <= 1'b0;
            O_tdata <= 96'd0; O_tvalid <= 1'b0; O_tuser <= 1'b0; O_tlast <= 1'b0;
        end else begin
            d  <= I_tdata;
            pd <= d;
            v1 <= I_tvalid;
            u1 <= I_tuser;
            l1 <= I_tlast;
            O_tdata  <= {r0,g0,b0, r1,g1,b1, r2,g2,b2, r3,g3,b3};
            O_tvalid <= v1;
            O_tuser  <= u1;
            O_tlast  <= l1;
        end
    end

endmodule

module blur121_h (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    input  wire        I_tuser,
    input  wire        I_tlast,
    output reg  [95:0] O_tdata,
    output reg         O_tvalid,
    output reg         O_tuser,
    output reg         O_tlast
);
    function [23:0] fb;
        input [23:0] l, m, r;
        reg [9:0] rr, gg, bb;
        begin
            rr = {2'b00, l[23:16]} + {1'b0, m[23:16], 1'b0} + {2'b00, r[23:16]};
            gg = {2'b00, l[15:8]}  + {1'b0, m[15:8],  1'b0} + {2'b00, r[15:8]};
            bb = {2'b00, l[7:0]}   + {1'b0, m[7:0],   1'b0} + {2'b00, r[7:0]};
            fb = {rr[9:2], gg[9:2], bb[9:2]};
        end
    endfunction

    reg [95:0] d_t;
    reg        d_v, d_u, d_l;
    reg [23:0] p3_d1, p3_d2;

    wire [23:0] d0 = d_t[95:72];
    wire [23:0] d1 = d_t[71:48];
    wire [23:0] d2 = d_t[47:24];
    wire [23:0] d3 = d_t[23:0];

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            d_t <= 96'd0; d_v <= 1'b0; d_u <= 1'b0; d_l <= 1'b0;
            p3_d1 <= 24'd0; p3_d2 <= 24'd0;
            O_tdata <= 96'd0; O_tvalid <= 1'b0; O_tuser <= 1'b0; O_tlast <= 1'b0;
        end
        else begin
            d_t   <= I_tdata;
            d_v   <= I_tvalid;
            d_u   <= I_tuser;
            d_l   <= I_tlast;
            p3_d1 <= I_tdata[23:0];
            p3_d2 <= p3_d1;

            O_tdata[95:72] <= fb(p3_d2, d0, d1);
            O_tdata[71:48] <= fb(d0, d1, d2);
            O_tdata[47:24] <= fb(d1, d2, d3);
            O_tdata[23:0]  <= fb(d2, d3, I_tdata[95:72]);
            O_tvalid <= d_v;
            O_tuser  <= d_u;
            O_tlast  <= d_l;
        end
    end
endmodule