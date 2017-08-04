%% Matches two TrackMate tracks based on their spot-spot distance.
% The tracks of the two files are loaded as list of spots. 

close all
clear
clc

% Calcium TrackMate XML file.
fileCalcium = '/Users/tinevez/Google Drive/Projects/Contacts/raw data/2015-09-17/Trackmate files/SiC - SAg_1_20_Calcium.xml';

% Contact TrackMate XML file.
fileContacts = '/Users/tinevez/Google Drive/Projects/Contacts/raw data/2015-09-17/Trackmate files/SiC - SAg_1_20_Contacts.xml';

% Minimal number of edges in calcium tracks below which tracks are not
% considered.
minNEdges = 60;

% Minimal number of edges in contact tracks below which tracks are not
% considered.
minNContactEdges = 5;

% Maximal mean distance between two tracks to accept a match.
maxTrackDist = 20; % physical units

% Plot tracks?
doPlot = true;

% Load colormap
load mycmap

%% Get calibration.

cal = trackmateImageCalibration(fileCalcium);
nFrames = cal.t.size;
fprintf('Found %d frames in source image.\n', nFrames)

%% Import calcium tracks.

fprintf('Loading Calcium XML file...\n')

[ tracksCalcium, tracksCalciumNames ] = loadtracks( fileCalcium, ...
    { 'POSITION_X', 'POSITION_Y', 'FRAME', 'MEAN_INTENSITY' } );

fprintf('Done.\n')

%% Filter calcium tracks.

nEdgesTracksCalcium = cellfun(@(x) size(x, 1), tracksCalcium );
tracksCalcium( nEdgesTracksCalcium < minNEdges ) = [];
tracksCalciumNames( nEdgesTracksCalcium < minNEdges ) = [];

fprintf('Retaining %d tracks out of %d.\n', numel( tracksCalcium ), numel( nEdgesTracksCalcium ) )

%% Import contact tracks.

fprintf('Loading Contact XML file...\n')

[ tracksContacts, tracksContactsNames ] = loadtracks( fileContacts, ...
    { 'POSITION_X', 'POSITION_Y', 'FRAME', 'QUALITY' } );

fprintf('Done.\n')

%% Filter contact tracks.

nEdgesTracksContacts = cellfun(@(x) size(x, 1), tracksContacts );
tracksContacts( nEdgesTracksContacts < minNContactEdges ) = [];
tracksContactsNames( nEdgesTracksContacts < minNContactEdges ) = [];

fprintf('Retaining %d tracks out of %d.\n', numel( tracksContacts ), numel( nEdgesTracksContacts ) )

%% Match.
fprintf('Matching calcium tracks to possible several contact tracks.\n')

ntCalcium = numel(tracksCalcium);
ntContacts = numel(tracksContacts);
matches = [];

if doPlot
    colors = 0.8 * hsv( ntCalcium );
    hf1 = figure('Position', [680   200   900   750]);
    hold on
end

for i = 1 : ntCalcium 

    fprintf('\nCalcium track %d of %d.\n', i, ntCalcium )
    
    trackCalcium = tracksCalcium{ i };
    framesCalcium = trackCalcium.FRAME + 1;
    posCalcium = [ trackCalcium.POSITION_X trackCalcium.POSITION_Y ];
    
    dpos2 = NaN( nFrames, 2 );
    dpos2( framesCalcium, : ) = posCalcium;
    
    distMean    = NaN( ntContacts, 1);
    distStd     = NaN( ntContacts, 1);
    distN       = NaN( ntContacts, 1);
    
    for j = 1 : ntContacts
        
        trackContact = tracksContacts{ j };
        framesContact = trackContact.FRAME + 1;
        posContact = [ trackContact.POSITION_X trackContact.POSITION_Y ];
        
        dpos1 = NaN( nFrames, 2 );
        dpos1( framesContact, : ) = posContact;
        
        delta = dpos1 - dpos2;
        dist = sqrt( sum(delta .* delta, 2) );
        distMean(j) = nanmean(dist);
        distStd(j) = nanstd(dist);
        distN(j) = numel( dist( ~isnan(dist) ) );
        
    end
    
    closeContacts = find( distMean < maxTrackDist );
    nCloseContacts = numel( closeContacts );
    
    
    if nCloseContacts == 0
        fprintf('Did not find a contact close to this calcium track.\n')
        continue
    end

    fprintf('Found %d contact tracks that matches calcium track #%d:\n', ...
        nCloseContacts, i )
    
    for j = 1 : nCloseContacts
        targetId = closeContacts(j);
        fprintf('\tcontact #%d -> calcium #%d - dist %.1f +/- %.1f %s N = %d spots.\n', ...
            targetId, i, distMean(targetId), distStd(targetId), cal.x.units, distN(targetId) )
    end
    
    if doPlot
        
        plot( posCalcium(:,1), posCalcium(:,2), ...
            'DisplayName', [ 'Calcium #' num2str(i) ], ...
            'Color', colors(i, :), ...
            'Marker', 's', ...
            'MarkerFaceColor',  colors(i, :))
        
        lx = min( posCalcium(:,1) );
        ux = max( posCalcium(:,1) );
        ly = min( posCalcium(:,2) );
        uy = max( posCalcium(:,2) );
        
        for j = 1 : nCloseContacts
            
            targetId = closeContacts(j);
            trackContact = tracksContacts{ targetId };
            posContact = [ trackContact.POSITION_X trackContact.POSITION_Y ];
            
            plot( posContact(:,1), posContact(:,2), ...
                'DisplayName', [ 'Contact #' num2str(target_id) ], ...
                'Color', colors(i, :), ...
                'Marker', 'o', ...
                'MarkerFaceColor',  'w')
                        
            lx = min(  [ lx ; posContact(:,1) ] );
            ux = max(  [ ux ; posContact(:,1) ] );
            ly = min(  [ ly ; posContact(:,2) ] );
            uy = max(  [ uy ; posContact(:,2) ] );
            
        end
        
        rectangle('Position', [ lx ly (ux-lx) (uy-ly) ], ...
            'EdgeColor', colors(i, :))
                
        text( ux , uy, ...
            [' Calcium: '  tracksCalciumNames{ i } ], ...        
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'Color', colors(i, :), ...
            'Interpreter', 'None')

    end

end


if doPlot
    xlabel([ 'X (' cal.x.units ')' ] )
    ylabel([ 'Y (' cal.y.units ')' ] )
    set(gca, 'TickDir', 'out', ...
        'YDir', 'reverse', ...
        'XAxisLocation', 'top')
    axis equal
end


% TODO: make stats of how many contacts per Calcium tracks. 

%% Plot kymographs.

nMatches = size(matches, 1);
fprintf('\nFound %d matches out of %d contact tracks.\n', nMatches, ntContacts)

kymograph = zeros( 2 * nMatches, nFrames );

% Look for min & max
% min_int = Inf;
% max_int = 0;

% for k = 1 : n_matches
%     
%     j = matches(k, 2);
%     track_1 = tracks_calcium{ j };
%     
%     intensity_raw = track_1(:,4);
%     min_int = min( min_int, min(intensity_raw) );
%     max_int = max( max_int, max(intensity_raw) );
% end

figure
hold on

for k = 1 : nMatches
   
    i = matches(k, 1);
    j = matches(k, 2);
    
    track_2 = tracksContacts{ i };
    trackCalcium = tracksCalcium{ j };

    frames_quality = track_2.FRAME + 1;
    quality = track_2.QUALITY;

    frames_intensity = trackCalcium.FRAME + 1;
    intensity_raw = trackCalcium.MEAN_INTENSITY;
    
    % Normalize min/max.
    intensity = intensity_raw / median(intensity_raw);
%     intensity = ( intensity - min(intensity) ) ./ ( max(intensity) - min(intensity) );
    
    plot(frames_intensity, intensity)
    
    contact = -0.5 * (quality > 0.01) - 0.5 * (quality > 0.2);
    kymograph( 2*k-1,   frames_quality ) = contact;
    kymograph( 2*k,     frames_intensity ) = intensity;

end

% cmap = [ 
%     repmat( [ 0.2 0.6 0.2 ], [ 32 1 ]);
%     repmat( [ 0.2 0.2 0.6 ], [ 32 1 ]);
%     0 0 0;
%     hot(64) ];


hf2 = figure('Position', [ 680    50   700   800 ] );
colormap(cmap4)
imagesc(kymograph)
box off 

for i = 1 : nMatches
   line( [0 nFrames], 0.5 + 2*[ i i ], ...
       'Color', 'w',...
       'LineWidth', 3)
    
end

set(gca, ...
    'TickDir', 'out', ...
    'YTick', 0.5 + 1 : 2 : 2 * nMatches, ...
    'YTickLabel', 1 : nMatches, ...
    'Position', [0.1300    0.1100    0.7    0.8150 ])
xlabel('Time (frames)')
ylabel('Track matches')

% Add 2nd axis.
ax1 = gca;
ax2 = axes(...
    'Units',get(ax1,'Units'), ...
    'Position',get(ax1,'Position'), ...
    'Parent',get(ax1,'Parent'), ...
	'YAxisLocation','right', ...
    'Color','none', ...
    'XGrid','off', ...
    'Xcolor', 'none', ...
    'YGrid','off',...
    'Box','off', ...
    'TickLabelInterpreter','none');
ylim( ax2, ylim( ax1 ) );


y2labels = cell( 2* nMatches, 1);
for i = 1 : nMatches
    j = matches(i, 2);
    y2labels{ 2 * i - 1 } = [' Contact: ' tracksContactsNames{ i } ];
    y2labels{ 2 * i  } = [' Calcium: '  tracksCalciumNames{ j } ];
end

set(ax2, ...
    'TickDir', 'out', ...
    'YTick', 1 : 2 * nMatches, ...
    'YTickLabel', y2labels)

[~, name] = fileparts(fileCalcium);
title(name, ...
    'Interpreter', 'None')


%% Save figures

return

saveNameTracks = [name '-tracks.pdf' ];
saveNameMatches = [name '-matches.pdf' ];

export_fig('-r600', saveNameTracks, hf1);
export_fig('-r600', '-opengl', saveNameMatches, hf2);

