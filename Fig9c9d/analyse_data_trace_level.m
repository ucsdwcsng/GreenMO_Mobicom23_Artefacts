function avg_sinr_across_users = analyse_data_trace_level(posn_index,data_dir, test_ids, algo_id,lts_thresh)
% sample values
% posn_index = 0;
% num_ant = 8;
% folder_name = "8ant_multipos_QAM16_34r"
% test_ids=1:1:3;
% avg_evm_snr_users_across_packets = zeros([num_tests,num_users]);
% min_evm_snr_users_across_packets = zeros([num_tests,num_users]);
% avg_sinr_users_across_packets = zeros([num_tests,num_users]);
% min_sinr_users_across_packets = zeros([num_tests,num_users]);
% avg_ber_users_across_packets = zeros([num_tests,num_users]);
% max_ber_users_across_packets = zeros([num_tests,num_users]);


% if LTS is not supplied
if(nargin==4)
    lts_thresh=0.6;
end

% clear vars to avoid matlab issues       
clear op_struct op_struct_cell rx_samps raw_rx_samps rx_samples_resamped ofdm_params_out 
clear avg_sinr avg_ber avg_snr_evm ber_dict evm_snr_dict sinr_dict
                    
%% Parameters and Flags
ofdm_params = wcsng_ofdm_param_gen(64);
ofdm_params.num_users = 4;

% bit_phase tells the experiment mode (internal naming)
expmt_mode ="bit_phase";
% Data is collected via all 8 antennas to 
% set up trace level evaluations
num_ant = 8;

% For OFDM RX
test_id = 1 ;
ofdm_params.num_packets = 400;
ofdm_params.packet_step_size = 1;
ofdm_params.MOD_ORDER = 16;
ofdm_params.NUM_LTS = 10;
num_lts_to_use = 10;
ofdm_params.inter_user_zeros = 512;

num_users = ofdm_params.num_users;
ofdm_params.enable_channel_codes = true;
% 
% root_dir = "C:\Users\agrim\Downloads\";
% savpath_dir = root_dir+"ag_data2/"+folder_name;
tx_params_dir = data_dir+"/tx_data"+num2str(num_users)+"/";
load(tx_params_dir+"ofdm_params_tx.mat");
expmt_str="rx_data"+num2str(num_ant)+"_"+num2str(posn_index);
path_dir = data_dir+"/"+expmt_str+"/";

disp("Processing for posn index: "+num2str(posn_index));

[tx_samples,ofdm_params] = ofdm_tx(ofdm_params); % Take tx packet and params from OFDM_tx.m
plot_debug=false;



num_tests = numel(test_ids);
% num_tests = 1;
avg_evm_snr_across_users = [];
avg_sinr_across_users = [];
avg_evm_snr_users_across_packets = zeros([num_tests,num_users]);
min_evm_snr_users_across_packets = zeros([num_tests,num_users]);
avg_sinr_users_across_packets = zeros([num_tests,num_users]);
min_sinr_users_across_packets = zeros([num_tests,num_users]);
avg_ber_users_across_packets = zeros([num_tests,num_users]);
max_ber_users_across_packets = zeros([num_tests,num_users]);

% num_rfc_to_use = 8;

for test_index = 1:1:num_tests
    % Load data
    test_idx = test_ids(test_index);
%     disp("Expmt: "+expmt_mode+", Test idx: "+num2str(test_idx)+", Users: "+num2str(num_users));
    fname = path_dir+"rx_samps_ch_est_"+num2str(test_idx);
    load(fname);
    % Phase align the traces across antennas, wrt to antenna 1 
    % need it for trace level simulations
    [rx_lts_all,rx_payload_only_all,rx_all_ltses,rx_payload_and_lts, chan_to_use_all, lts_offsets,ret_val] = get_phase_aligned_traces(rx_samps_ch_est,ofdm_params);
    if(ret_val==-1)
%        disp("Expmt: "+expmt_mode+", Test idx: "+num2str(test_idx)+", Users: "+num2str(num_users)+" LTS not found");
        continue
    end
    %% implement analog algos here
    % BABF 4x, 6x, 8x
    % Dig BF 4x,6x,8x
    % PC 8-4
    % FC 8-4

    if(algo_id==1) % 4 ant DBF
        num_rfc_to_use = 4;
        rx_lts = rx_lts_all(:,:,:,8-num_rfc_to_use+1:8,:);
        chan_to_use = chan_to_use_all(8-num_rfc_to_use+1:8,:,:);
        rx_payload_only = rx_payload_only_all(:,8-num_rfc_to_use+1:8,:);
    elseif(algo_id==2) % 6 ant DBF
        num_rfc_to_use = 6;
        rx_lts = rx_lts_all(:,:,:,8-num_rfc_to_use+1:8,:);
        chan_to_use = chan_to_use_all(8-num_rfc_to_use+1:8,:,:);
        rx_payload_only = rx_payload_only_all(:,8-num_rfc_to_use+1:8,:);    
    elseif(algo_id==3) % 8 ant DBF
        num_rfc_to_use = 8;
        rx_lts = rx_lts_all(:,:,:,1:num_rfc_to_use,:);
        chan_to_use = chan_to_use_all(1:num_rfc_to_use,:,:);
        rx_payload_only = rx_payload_only_all(:,1:num_rfc_to_use,:);
    
    elseif(algo_id==4) % PC Hybrid

        babf_chan_inp = squeeze(chan_to_use_all(:,:,2)); % 4th subcarrier
        babf_chan_inp_norm = babf_chan_inp./abs(babf_chan_inp);

        partial_ant_mat = [[1,1,0,0,0,0,0,0];...
                           [0,0,1,1,0,0,0,0];...
                           [0,0,0,0,1,1,0,0];...
                           [0,0,0,0,0,0,1,1]];
        hyb_chan_mat = partial_ant_mat.*(babf_chan_inp'); % conjugate

        rx_lts_reduced = rx_lts_all(:,:,:,1:1:4,:);
        rx_payload_only_reduced = rx_payload_only_all(:,1:1:4,:);
        rx_payload_only = zeros(size(rx_payload_only_reduced));
        rx_lts = zeros(size(rx_lts_reduced));
        

        for rfc_idx_iter = 1:1:4
            for ant_idx = 1:1:8
                rx_lts(:,:,:,rfc_idx_iter,:) = rx_lts(:,:,:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_lts_all(:,:,:,ant_idx,:) ;
                rx_payload_only(:,rfc_idx_iter,:) = rx_payload_only(:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_payload_only_all(:,ant_idx,:) ;
            end
        end
        
        chan_to_use_red = chan_to_use_all(1:1:4,:,:);
        chan_to_use = zeros(size(chan_to_use_red));
        for subc_idx=1:1:64
            chan_to_use(:,:,subc_idx) = (hyb_chan_mat)*squeeze(chan_to_use_all(:,:,subc_idx));
        end

    elseif(algo_id==5) %  Intmd Hybrid
        
        babf_chan_inp = squeeze(chan_to_use_all(:,:,2)); % 4th subcarrier
        babf_chan_inp_norm = babf_chan_inp./abs(babf_chan_inp);
        
        partial_ant_vec=1:1:4;
        partial_ant_mat = [[1,1,1,1,0,0,0,0];...
                           [0,0,1,1,1,1,0,0];...
                           [0,0,0,0,1,1,1,1];...
                           [1,1,0,0,0,0,1,1]];

        hyb_chan_mat = partial_ant_mat.*(babf_chan_inp');
%         hyb_num_rfc = 4;
%         num_ants_per_rfc = 2;
%         partial_ant_vec = reshape(partial_ant_vec,[num_ants_per_rfc,hyb_num_rfc]).';

%         for rfc_idx_iter = 1:1:4
%             for ant_idx = partial_ant_vec(rfc_idx_iter,:)
%                 hyb_chan_mat(rfc_idx_iter,ant_idx) = babf_chan_inp(ant_idx,rfc_idx_iter);
%             end
%         end
%         babf_mat = analog_beamf_config_choser(babf_chan_inp,8,1:1:8,pi/4);
%         babf_mat_all_subc = repmat(babf_mat,[1,1,64]);
        rx_lts_reduced = rx_lts_all(:,:,:,1:1:4,:);
        rx_payload_only_reduced = rx_payload_only_all(:,1:1:4,:);
        rx_payload_only = zeros(size(rx_payload_only_reduced));
        rx_lts = zeros(size(rx_lts_reduced));
        

        for rfc_idx_iter = 1:1:4
            for ant_idx = 1:1:8
                rx_lts(:,:,:,rfc_idx_iter,:) = rx_lts(:,:,:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_lts_all(:,:,:,ant_idx,:) ;
                rx_payload_only(:,rfc_idx_iter,:) = rx_payload_only(:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_payload_only_all(:,ant_idx,:) ;
            end
        end
        
        chan_to_use_red = chan_to_use_all(1:1:4,:,:);
        chan_to_use = zeros(size(chan_to_use_red));
        for subc_idx=1:1:64
            chan_to_use(:,:,subc_idx) = (hyb_chan_mat)*squeeze(chan_to_use_all(:,:,subc_idx));
        end
    
    elseif(algo_id==6) % FC Hybrid
        
        babf_chan_inp = conj(squeeze(chan_to_use_all(:,:,3))); % 4th subcarrier
        babf_chan_inp_norm = babf_chan_inp./abs(babf_chan_inp);


        hyb_chan_mat = babf_chan_inp.';

        rx_lts_reduced = rx_lts_all(:,:,:,1:1:4,:);
        rx_payload_only_reduced = rx_payload_only_all(:,1:1:4,:);
        rx_payload_only = zeros(size(rx_payload_only_reduced));
        rx_lts = zeros(size(rx_lts_reduced));
        

        for rfc_idx_iter = 1:1:4
            for ant_idx = 1:1:8
                rx_lts(:,:,:,rfc_idx_iter,:) = rx_lts(:,:,:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_lts_all(:,:,:,ant_idx,:) ;
                rx_payload_only(:,rfc_idx_iter,:) = rx_payload_only(:,rfc_idx_iter,:)+hyb_chan_mat(rfc_idx_iter,ant_idx)*rx_payload_only_all(:,ant_idx,:) ;
            end
        end
        
        chan_to_use_red = chan_to_use_all(1:1:4,:,:);
        chan_to_use = zeros(size(chan_to_use_red));
        for subc_idx=1:1:64
            chan_to_use(:,:,subc_idx) = (hyb_chan_mat)*squeeze(chan_to_use_all(:,:,subc_idx));
        end
    end
    

    
    %% combine and analyse: Get SINRS from the LTSs
    %packets,ofdm_params.NUM_LTS,num_users,total_rfc,num_subc);
    [num_packets,~,~,num_rfc,num_subc] = size(rx_lts);
    
    nonnull_subc = [2:27 39:64];
    num_nonnull_subc = numel(nonnull_subc);
    % rx_lts = zeros(num_packets,ofdm_params.NUM_LTS,num_users,num_rfc,num_subc);
    combined_lts_f = zeros(num_packets,num_users,num_users,ofdm_params.NUM_LTS,num_subc);
    user_comb_vecs = zeros(num_users,num_rfc,num_subc);
    tdma_snrs = zeros(num_packets,num_users,num_rfc,num_nonnull_subc);
    
    %% ofdm lengths
    sing_lts_len = ofdm_params.N_SC; 
    lts_len_singuser = (((ofdm_params.NUM_LTS+0.5)*sing_lts_len)); % 10 LTS + 0.5 CP
    lts_len = (((ofdm_params.NUM_LTS+0.5)*sing_lts_len)+ofdm_params.inter_user_zeros)*num_users; % total preamb len
    payload_len = (ofdm_params.N_SC+ofdm_params.CP_LEN)*ofdm_params.N_OFDM_SYMS+0.5*ofdm_params.inter_user_zeros;
    payload_len_ceiled = ceil(payload_len/(ofdm_params.N_SC+ofdm_params.CP_LEN))*(ofdm_params.N_SC+ofdm_params.CP_LEN);
    pkt_and_payload_plus_zeros = payload_len_ceiled+lts_len; % +0.5*ofdm_params.inter_user_zeros for multipath
    num_subc_groups = pkt_and_payload_plus_zeros/ofdm_params.N_SC;
    num_syms_group = ceil(payload_len/(ofdm_params.N_SC+ofdm_params.CP_LEN));
    rx_payload_only_cp_reshaped = reshape(rx_payload_only,num_packets,num_rfc,num_subc+ofdm_params.CP_LEN,num_syms_group);
    rx_payload_only_cp_rem = rx_payload_only_cp_reshaped(:,:,ofdm_params.CP_LEN+1:num_subc+ofdm_params.CP_LEN,:);
    rx_payload_f = fft(rx_payload_only_cp_rem,64,3); 
    combined_payload_and_lts_f = zeros(num_packets,num_users,num_subc,num_syms_group);
    
    %% Digital Combining codes now finally
    skip_combining = false;
    for pkt_idx=1:1:num_packets
        % Get freq domain LTS's for each packet
        if(num_users>1)
            rx_lts_f = fft(squeeze(rx_lts(pkt_idx,:,:,:,:)),num_subc,4);% 4th axis is subcarrier
        else
            rx_lts_f = fft(squeeze(rx_lts(pkt_idx,:,:,:,:)),num_subc,3);% 4th axis is subcarrier
        end
        % perform combining per subcarrier
        for subc_idx=1:1:num_nonnull_subc 
            % Finally obtain narrowband channel matrix for each subc
            if(num_users==1)
                chan_mat = chan_to_use(:,nonnull_subc(subc_idx));
            else
                chan_mat = chan_to_use(:,:,nonnull_subc(subc_idx));
            end
            % Now go on and implement digital combining
            for user_idx=1:1:num_users
                if(num_users>1)
                    %% MMSE postcoding
                    noise_rat = 10^(30/10);
                    H_hat = chan_mat;
%                     norm_H_hat=H_hat/norm(H_hat,'fro');
%                     inv_mat=inv(norm_H_hat*(norm_H_hat')+eye(num_users)/noise_rat);
%                     W=(norm_H_hat.')*inv_mat;
                    if(skip_combining)
                        W=eye(num_users);
                    else
                        W = pinv(H_hat);
                    end
%                     W=W/norm(W,'fro');
                    fin_comb_vec = W(user_idx,:).';
                    user_comb_vecs(user_idx,:,nonnull_subc(subc_idx)) = fin_comb_vec;
                    %% Combine with W
                    
                    curr_payload_to_be_combined = squeeze(rx_payload_f(pkt_idx,:,nonnull_subc(subc_idx),:)).';
                    repmat_combvec = repmat(fin_comb_vec.',[num_syms_group,1]);
                    combined_samp = sum(curr_payload_to_be_combined.*repmat_combvec,2); % RFCs are getting summed over here
                    combined_payload_and_lts_f(pkt_idx,user_idx,nonnull_subc(subc_idx),:)=combined_samp;
                    
                    %% Compute TDMA SNRs from uncombined LTS's in freq domain (For each packet and each subcarrier)
                    curr_lts_tdmasnr = squeeze(rx_lts_f(:,user_idx,:,nonnull_subc(subc_idx)));
                    sig_pow = squeeze(mean(abs(curr_lts_tdmasnr).^2,1));
                    noise_pow = squeeze(var(abs(curr_lts_tdmasnr),0,1));
                    tdma_snrs(pkt_idx,user_idx,:,subc_idx) = sig_pow./noise_pow;

                    for comb_user_idx=1:1:num_users
                        curr_lts_to_be_combined = squeeze(rx_lts_f(:,comb_user_idx,:,nonnull_subc(subc_idx)));
                        repmat_combvec = repmat(fin_comb_vec.',[ofdm_params.NUM_LTS,1]);
                        combined_samp = sum(curr_lts_to_be_combined.*repmat_combvec,2);
                        combined_lts_f(pkt_idx,user_idx,comb_user_idx,:,nonnull_subc(subc_idx))=combined_samp;     
                    end
                else
                    %% Just populat stuff for single user case, no need for any coding
                    ref_chain_idx =1;
                    curr_payload_to_be_combined = squeeze(rx_payload_and_lts_groups_64_f(pkt_idx,ref_chain_idx,nonnull_subc(subc_idx),:)).';
                    curr_lts_to_be_combined = squeeze(rx_lts_f(:,ref_chain_idx,nonnull_subc(subc_idx)));

                    sig_pow = squeeze(mean(abs(curr_lts_to_be_combined).^2,1));
                    noise_pow = squeeze(var(abs(curr_lts_to_be_combined),0,1));
                    tdma_snrs(pkt_idx,user_idx,:,subc_idx) = sig_pow./noise_pow;

                    combined_lts_f(pkt_idx,user_idx,user_idx,:,nonnull_subc(subc_idx))=curr_lts_to_be_combined;
                    combined_payload_and_lts_f(pkt_idx,user_idx,nonnull_subc(subc_idx),:)=curr_payload_to_be_combined;
                end
            end
        end
    end
    
    %% Analysis, EVM BER and all other metrics
    % get back to time domain and flatten the array
    combined_lts_t = ifft(combined_lts_f,num_subc,5);
    combined_payload_t = ifft(combined_payload_and_lts_f,num_subc,3);
    combined_payload_t_plus_cp = zeros(num_packets,num_users,num_subc+ofdm_params.CP_LEN,num_syms_group);
    combined_payload_t_plus_cp(:,:,1:ofdm_params.CP_LEN,:) = combined_payload_t(:,:,num_subc-ofdm_params.CP_LEN+1:num_subc,:);
    combined_payload_t_plus_cp(:,:,ofdm_params.CP_LEN+1:ofdm_params.CP_LEN+num_subc,:) = combined_payload_t;
    combined_payload_fin = reshape(combined_payload_t_plus_cp,num_packets,num_users,payload_len_ceiled,[]);
    if(plot_debug)
        pkt_idx = 1;
        figure(83)
        num_rows=2;
        num_cols=ceil(num_users/num_rows); 
        for i=1:1:num_users
            subplot(num_cols,num_rows,i)
            all_rx_lts=[];
            for ii=1:1:num_users
                all_rx_lts = [all_rx_lts  zeros(1,0.5*sing_lts_len)];
                for j=1:1:ofdm_params.NUM_LTS
                    % combined_lts_f = zeros(num_packets,num_users,num_users,ofdm_params.NUM_LTS,num_subc);
                    % combined_lts_f(pkt_idx,user_idx,comb_user_idx,:,nonnull_subc(subc_idx))=combined_samp;     
                    all_rx_lts = [all_rx_lts squeeze(combined_lts_t(pkt_idx,i,ii,j,:)).'];
                end
                all_rx_lts = [all_rx_lts  zeros(1,ofdm_params.inter_user_zeros)];
            end
            all_rx_lts = all_rx_lts .'; 
            
            
%             plot([abs(squeeze(rx_all_ltses(pkt_idx,i,:))).' abs(squeeze(rx_payload_only(pkt_idx,i,:))).']);
%             hold on
            plot([abs(all_rx_lts).' squeeze(abs(combined_payload_fin(pkt_idx,i,:))).']);
        end
    end
                                             % pkt,user,user,10lts,nonnulls
    combined_lts_f_non_null = combined_lts_f(:,:,:,:,nonnull_subc);
    
    % these are the things you need
    sinr_calc = zeros(num_packets,num_users,num_nonnull_subc );
    ber_calc = zeros(num_packets,num_users);
    evm_snr_calc = zeros(num_packets,num_users);
    
    clear all_users_decode_struct
    for pkt_idx=1:1:num_packets
        clear decode_params decode_op_structs
        for user_idx=1:1:num_users
            subc_pow_profile = (abs(squeeze(combined_lts_f_non_null(pkt_idx,user_idx,:,:,:))).^2);
            if(num_users>1)
                mean_pow_per_comb_user = squeeze(mean(subc_pow_profile,2)); %mean across 10lts
                subc_mag_profile = abs(squeeze(combined_lts_f_non_null(pkt_idx,user_idx,:,:,:)));
                noise_pow = squeeze(var(subc_mag_profile(user_idx,:,:),0,2));
                sig_pow = mean_pow_per_comb_user(user_idx,:).';
                curr_user = user_idx;
                user_vec = 1:1:num_users;
                interf_users = user_vec;
                interf_users(curr_user) =[];
                interf_pow = sum(mean_pow_per_comb_user(interf_users,:),1).';
                if(skip_combining)
                	sinr_vec = sig_pow./(noise_pow);
                else
                    sinr_vec = sig_pow./(interf_pow+noise_pow);
                end
                sinr_calc(pkt_idx,user_idx,:) = sinr_vec;
            else
                mean_pow_per_comb_user = squeeze(mean(subc_pow_profile,1)); %mean across 10lts
                subc_mag_profile = abs(squeeze(combined_lts_f_non_null(pkt_idx,user_idx,:,:,:)));
                noise_pow = squeeze(var(subc_mag_profile,0,1));
                sig_pow = mean_pow_per_comb_user(user_idx,:);
                sinr_vec = sig_pow./(noise_pow);
                
                sinr_calc(pkt_idx,user_idx,:) = sinr_vec; 
            end    
        end
    end
    

    mean_sinr_per_packet = 10*log10(mean(sinr_calc,[2,3]));
    cleaned_sinrs_per_packet = remove_outliers(mean_sinr_per_packet);
    
    all_sinrs = cleaned_sinrs_per_packet;
    avg_sinr_across_users = [avg_sinr_across_users all_sinrs.'];


end

% disp("Finished analysis, Mean SINR: "+num2str(mean(avg_sinr_across_users)))

end

function cleaned_vec = remove_outliers(data_vec)
    tol = 2;
    std_data = std(data_vec);
    mean_data = mean(data_vec);
    cleaned_vec = data_vec;
    cleaned_vec(abs(data_vec-mean_data)>tol*std_data)=[];
    % -5 because of discrepancy in calculating the SINRs from
    % EVM versus the LTS method for trace level comparison
    cleaned_vec = cleaned_vec-5; 
end

function delayed_sig = delayseq2(curr_sig, frac_del)
    nfft = numel(curr_sig);
    fbins = 2 * pi * ifftshift((0:1:nfft-1) - floor(nfft/2)) / nfft;
    X = fft(curr_sig.', nfft);
    delayed_sig = ifft(X .* exp(-1j * frac_del * fbins));
end

function switched_beamf_mat = analog_beamf_config_choser(beamf_mat_all_users,num_ants_to_use,ants_to_use,inphase_val)
    [max_ants,num_users] = size(beamf_mat_all_users);
    mat_to_use = beamf_mat_all_users(ants_to_use,:);
    non_invert_chan_mat = true;
    ant_idx_perf=1;
    perf_choice = ones(1,num_users); % choose the best ones if possible
    while(non_invert_chan_mat)
        switched_beamf_mat= zeros(max_ants,num_users);
        if(sum(perf_choice>ceil(max_ants/2)+1)>0)
            break
        end
        for user_idx=1:1:num_users
            antenna_score_func = zeros(1,num_ants_to_use);
            antenna_configs = zeros(num_ants_to_use,num_ants_to_use);
            curr_vec = mat_to_use(:,user_idx); % user's channel 
            for ant_idx=1:1:num_ants_to_use % iterate over all antennas
                curr_phase = mat_to_use(ant_idx,user_idx);
                conj_vec = curr_vec*conj(curr_phase); % conjugate multiplication allows to compute angle
                antenna_configs(ant_idx,:) = abs(angle(conj_vec))<inphase_val; % see if angle is less than the desired inphase angle
                antenna_score_func(ant_idx) = -sum(antenna_configs(ant_idx,:)); % sort does asc, want to choose most number of antennas
            end
            [~,antenna_perf_order] = sort(antenna_score_func); % sort such that my configs which show highest numnber of antennas are on top
            switched_beamf_mat(ants_to_use,user_idx) = antenna_configs(antenna_perf_order(perf_choice(user_idx)),:); % choose from the perf order
        end
        
        rank_val = rank(switched_beamf_mat);
        if(rank_val==num_users) % exit out of the loop if rank is full
            non_invert_chan_mat=false;
            break
        else
            perf_choice(ant_idx_perf)=perf_choice(ant_idx_perf)+1;
            ant_idx_perf=mod((ant_idx_perf+1)-1,num_users)+1;
        end
            
    end
    
    
    while(non_invert_chan_mat)
%         if(num_ants_to_use==4)
%             switched_beamf_mat= zeros(max_ants,num_users);
%             switched_beamf_mat(ants_to_use,:) = fliplr(eye(4));
%             disp("Unable to find invertible analog soln, supplying identity mat")
%             break
%         end
        switched_beamf_mat= zeros(max_ants,num_users);
        switched_beamf_mat(ants_to_use,:) = randi(2,num_ants_to_use,num_users)-1;
        if(rank(switched_beamf_mat)==num_users)
            non_invert_chan_mat=false;
            disp("Unable to find invertible analog soln, supplying random mat")
            break
        end
    end

    
end


