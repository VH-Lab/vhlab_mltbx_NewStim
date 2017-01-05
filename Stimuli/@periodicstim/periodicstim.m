function [pso] = periodicstim(PSparams,OLDSTIM);

% NewStim package: PERIODICSTIM
%
%  THEPERIODICSTIM = PERIODICSTIM(PARAMETERS)
%
%  Creates a periodic stimulus, such as a sine-wave grating, saw-tooth grating,
%  etc.  This class is a wrapper to the stimuli in the StimGen package.  Note
%  that this package is gray-scale only, so color values are given between 0-1.
%
%  The PARAMETERS argument can either be a structure containing the parameters
%  or the string 'graphical'(in which case the user is prompted for the values
%  of the parameters), or the string 'default' (in which case default parameter
%  values are assigned). In the graphical case, the following call is available:
%
%  THEPERIODICSTIM = PERIODICSTIM('graphical',OLDSTIM)
%
%  in which case the default parameters presented are based on OLDSTIM.  If the
%  values are being passed, then PARAMETERS should be a structure with the
%  following fields (fields are 1x1 unless indicated):
%
%  imageType       -   0 => field (single luminance across field) 
%                      1 => square (field split into light and dark halves)
%                      2 => sine (smoothly varying shades)
%                      3 => triangle (linear light->dark->light transition)
%                      4 => lightsaw (linear light->dark transition)
%                      5 => darksaw (linear dark->light transition)
%                      6 => <sFrequency> bars of <barwidth> width (see below)
%                      7 => edge (like lightsaw but with bars determining width
%                           of saw)
%                      8 => bump (bars with internal smooth dark->light->dark
%                           transitions
%  animType        -   0 => no animation
%                      1 => square wave
%                      2 => sine wave
%                      3 => ramp
%                      4 => drifting grating
%                      5 => fixed on-duration flicker for field stimulus
%  flickerType     -   0 => light > background -> light
%                      1 => dark -> background -> dark
%                      2 => counterphase
%  angle           -   orientation, in degrees, 0 is up
%  distance        -   distance of the monitor from the viewer
%  sFrequency      -   spatial frequency in cycles per degree
%  tFrequency      -   temporal frequency (Hz)
%  sPhaseShift     -   Phase shift (only works for counterphase stims but must
%                      be passed for all), in radians  where 2*pi is 1 cycle
%  barWidth        -   Width of bar (% of display rgn), only valid for bar stims
%                      but must have value passed for all stims.
%  [1x4] rect      -   The rectangle on the screen where the stimulus will be
%                      displayed:  [ top_x top_y bottom_x bottom_y ]
%  nCycles         -   The number of times the stimulus should be repeated
%  contrast        -   0-1: 0 means no diff from background, 1 is max difference
%  background      -   luminance of the background (0-1 from chromlow to chromhigh)
%  backdrop        -   luminance of area outside of display region
%                       If [1x1] then it is 0-1 from chromlow to chromhigh
%                       If [1x3] then it specifies actual rgb color
%  barColor        -   For bar stimuli, the color of the bars (0-1)
%  nSmoothPixels   -   Blurs the image with a boxcar of this width
%  fixedDur        -   fixed on-duration of squarewave flicker
%  windowShape     -   0 rectangle,1 oval,2 oriented rectangle,3 oriented oval
%                  -     6 - rectangle with aperture removed; requires
%                            extra parameter 'aperture' [aperture_x aperture_y]
%                  -     7 - oval with aperture removed; requires extra
%                            parameter 'aperture' [aperture_x aperture_y]
%                  -     8 - gaussian windowed (sigma_x=0.33*width/sqrt(8*log(2)) )
%                                              (sigma_y=0.33*height/sqrt(8*log(2)) )
%  loops           -   Number of back-and-forth loops.  0, the default, means
%                        only forward motion, 1 is a single loop forward and
%                        backward, 2 is forward backward forward, etc.
%
%  Optional parameters:
%  phaseSequence   -   Present the grating as a sequence of phase steps
%  phaseSteps      -   Number of total phase steps
%
%  See also:  STIMULUS, STOCHASTICGRIDSTIM, PERIODICSCRIPT

NewStimListAdd('periodicstim');

if nargin==0,
	pso = periodicstim('default');
	return;
end;

finish = 1;

default_p = struct( ...
                           'imageType',         2,              ...
                           'animType',          4,              ...
                           'flickerType',       0,              ...
                           'angle',             45,             ...
			   'chromhigh',		255*[1 1 1],	...
			   'chromlow',		[0 0 0],	...
                           'sFrequency',        1,              ...
                           'sPhaseShift',       0,              ...
                           'distance',          57,             ...
                           'tFrequency',        4,              ...
                           'barWidth',          0.5,            ...
                           'rect',       [100 100 200 200],     ...
                           'nCycles',           10,             ...
                           'contrast',          1,         		 ...
                           'background',        0.5,            ...
                           'backdrop',    		0.5,            ...
                           'barColor',          1,              ...
                           'nSmoothPixels',     2,              ...
                           'fixedDur',          0,              ...
                           'windowShape',       1,              ...
                           'loops',             0               ...
                           );
default_p.dispprefs = {};

if nargin==1, oldstim=[]; else, oldstim = OLDSTIM; end;

if ischar(PSparams),
	if strcmp(PSparams,'graphical'),
		% load parameters graphically
                p = get_graphical_input(oldstim);
                if isempty(p), finish = 0; else, PSparams = p; end;
	elseif strcmp(PSparams,'default'),
		PSparams = default_p;
	else,
		error('Unknown string input into periodicstim.');
	end;
else,   % they are just parameters
	[good, err] = verifyperiodicstim(PSparams);
	if ~good, error(['Could not create periodicstim: ' err]); end;
end;

if finish,
	
	cpustr = computer;
	if (strcmp(cpustr,'MAC2')),  % if we have a Mac
		
		StimWindowGlobals;
		tRes = round( (1/PSparams.tFrequency) * StimWindowRefresh);
		% screen frames / cycle
		
		%compute displayprefs info
		
		fps = StimWindowRefresh;
		
	else,  % we're just initializing
		tRes = 5;
		fps = -1;
		
	end;

	if isfield(PSparams,'loops'), loops = PSparams.loops; else, loops = 0; end;

	if isfield(PSparams,'aperature'), PSparams.aperture = PSparams.aperature; % correct steve's bad bad spelling
	elseif isfield(PSparams,'aperture'), PSparams.aperature = PSparams.aperture;  % correct for steve's bad bad spelling
	end;

	frames = (1:tRes*PSparams.nCycles);
	loopdir = 1;
	while loops>0,
		loopdir = loopdir * -1;
		if loopdir>0,
			frames = [frames 1:tRes*PSparams.nCycles];
		else,
			frames = [frames tRes*PSparams.nCycles:-1:1,];
		end;
		loops = loops - 1;
	end;
	
	% Special case: animType == 1  %% actually let's just forget this as a special case even though it wastes some time
	%if (PSparams.animType == 1) % if a square wave, only 2 frames:  ON and OFF
	%	fps = 0.5 * PSparams.tFrequency;
	%	disp(['here']);
		%f = PSparams.tFrequency;
		%t = 0.00001 + (0:1/StimWindowRefresh:PSparams.nCycles/f);
		%x = zeros(size(t)); x(find(sin(f*2*pi*t)<0)) = 1; x(find(sin(f*2*pi*t)>=0)) = 2;
	%	frames = repmat(1:2,1,PSparams.nCycles);  % x
	%end;

	oldRect = PSparams.rect;
	width = oldRect(3) - oldRect(1); height = oldRect(4)-oldRect(2);
	dims = max(width,height);
	newrect = [oldRect(1) oldRect(2) oldRect(1)+dims oldRect(2)+dims];
	if PSparams.windowShape>=2&PSparams.windowShape<=8,
		extra = 0; if PSparams.windowShape>=4, extra = 90; end;
		angle = mod(PSparams.angle+extra,360)/180*pi;
		trans = [cos(angle) -sin(angle); sin(angle) cos(angle)];
		ctr = [mean(oldRect([1 3])) mean(oldRect([2 4]))];
		cRect=(trans*([oldRect([1 2]);oldRect([3 2]);...
				oldRect([3 4]);oldRect([1 4])]-...
				repmat(ctr,4,1))')'+repmat(ctr,4,1);
		dimnew = [max(cRect(:,1))-min(cRect(:,1)) ...
					max(cRect(:,2))-min(cRect(:,2))];
		ID = max(dimnew);
		newrect = ([-ID -ID ID ID]/2+repmat(ctr,1,2));
	end;

	dp={'fps',fps, ...
	'rect',newrect, ...
	'frames',frames,PSparams.dispprefs{:} };
	s = stimulus(5);
	data = struct('PSparams', PSparams);
	pso = class(data,'periodicstim',s);
	pso.stimulus = setdisplayprefs(pso.stimulus,displayprefs(dp));
	
else
	pso = [];
end;




%%% GET_GRAPHICAL_INPUT funciton %%%

function params = get_graphical_input(oldstim)

if isempty(oldstim),
	rect_str = '[100 100 191 191]';
	image_val = 3; anim_val = 5; flicker_val = 1;
	angle_str = '90'; sFrequency_str = '0.5';
	tFrequency_str = '4';
	nCycles_str = '10';
%	durtn_str = '2';
	distance_str = '57';
	contrast_str = '1'; background_str = '0.5';backdrop_str = '0.5';
	smooth_str = '2'; shape_val = 2; barColor_str = '1';
	barWidth_str = '0.5'; sPhase_str = '0'; fixed_str = '0';
	dp_str = '{}';
	chromhigh_str = '[255 255 255]';
	chromlow_str = '[0 0 0]';
	loops_str = '0';
else,
	oldS = struct(oldstim); PSparams = oldS.PSparams;
	rect_str = mat2str(PSparams.rect);
	image_val = (PSparams.imageType+1);
	anim_val = (PSparams.animType+1);
	flicker_val = (PSparams.flickerType+1);
	angle_str = num2str(PSparams.angle);
	chromhigh_str = mat2str(PSparams.chromhigh);
	chromlow_str = mat2str(PSparams.chromlow);
	sFrequency_str = num2str(PSparams.sFrequency);
	tFrequency_str = num2str(PSparams.tFrequency);
	nCycles_str = num2str(PSparams.nCycles);
%	durtn_str = num2str(round(PSparams.nCycles/PSparams.tFrequency));
	distance_str = num2str(PSparams.distance);
	contrast_str = num2str(PSparams.contrast);
	background_str = num2str(PSparams.background);
	backdrop_str = mat2str(PSparams.backdrop);
	smooth_str = num2str(PSparams.nSmoothPixels);
	shape_val = (PSparams.windowShape+1);
	barColor_str = num2str(PSparams.barColor);
	barWidth_str = num2str(PSparams.barWidth);
	sPhase_str = num2str(PSparams.sPhaseShift);
	fixed_str = num2str(PSparams.fixedDur);
	dp_str = wimpcell2str(PSparams.dispprefs);
        if isfield(PSparams,'loops'),
                loops_str = num2str(PSparams.loops);
        else, loops_str = '0';
        end;
end;


% make figure layout
h0 = figure('Color',[0.8 0.8 0.8],'Position',[196 100 415 525]);
settoolbar(h0,'none'); set(h0,'menubar','none');

% window heading
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'FontSize',18, ...
        'FontWeight','bold', ...
        'ListboxTop',0, ...
        'Position',[42 476 285 25], ...
        'String','New periodicstim object...', ...
        'Style','text', ...
        'Tag','StaticText1');

% entry for any displaypref options
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 445 344 19], ...
        'String','Set any displayprefs options here: example: {''BGpretime'',1}', ...
        'Style','text', ...
        'Tag','StaticText2');
dp_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 425 365 19], ...
        'String',dp_str, ...
        'Style','edit', ...
        'Tag','EditText1');
		  
% entry for size of stimulus display
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[24 396 225 15], ...
        'String','[1x4] Rect [top_x top_y bottom_x bottom_y]', ...
        'Style','text', ...
        'Tag','StaticText2');
rect_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[255 396 135 18], ...
        'String',rect_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% image type entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[24 370 53 19], ...
        'String','image type', ...
        'Style','text', ...
        'Tag','StaticText2');
image_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'ListboxTop',0, ...
        'Min',1, ...
        'Position',[85 375 75 16], ...
        'String',{'field','square','sine','triangle','lightsaw','darksaw','bars','edge','bump'}, ...
        'Style','popupmenu', ...
        'Tag','PopupMenu1', ...
        'Value',image_val);

% flicker type entrly
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[185 370 40 19], ...
        'String','flicker', ...
        'Style','text', ...
        'Tag','StaticText2');
flicker_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'ListboxTop',0, ...
        'Min',1, ...
        'Position',[225 375 165 16], ...
        'String',{'light->background->light','dark->background->dark','counterphase'},...
        'Style','popupmenu', ...
        'Tag','PopupMenu1', ...
        'Value',flicker_val);

% animation type entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 344 50 19], ...
        'String','animation', ...
        'Style','text', ...
        'Tag','StaticText2');
anim_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'ListboxTop',0, ...
        'Min',1, ...
        'Position',[85 350 120 16], ...
        'String',{'static','square','sine','ramp','drifting','fixed on-duration (field only)'}, ...
        'Style','popupmenu', ...
        'Tag','PopupMenu1', ...
        'Value',anim_val);
		  
% stimulus shape entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[215 344 90 19], ...
        'String','Shape of stimulus', ...
        'Style','text', ...
        'Tag','StaticText2');
shape_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'ListboxTop',0, ...
        'Min',1, ...
        'Position',[308 350 81 16], ...
        'String',{'rectangle','oval','angled rect','angled oval','n/a','n/a','n/a','n/a','gaussian'}, ...
        'Style','popupmenu', ...
        'Tag','PopupMenu1', ...
        'Value',shape_val);

% angle of orientation entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 317 120 19], ...
        'String','[1x1] angle, 0 is up', ...
        'Style','text', ...
        'Tag','StaticText2');
angle_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 321 40 19], ...
        'String',angle_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% spatial frequency entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[230 317 130 19], ...
        'String','[1x1] spatial frequency', ...
        'Style','text', ...
        'Tag','StaticText2');
sFrequency_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[350 321 40 19], ...
        'String',sFrequency_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% temporal frequency entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 295 130 19], ...
        'String','[1x1] temporal frequency', ...
        'Style','text', ...
        'Tag','StaticText2');
tFrequency_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 299 40 19], ...
        'String',tFrequency_str, ...
        'Style','edit', ...
        'Tag','EditText1');

 % number of cycles entry		  
 h1 = uicontrol('Parent',h0, ...
         'Units','pixels', ...
         'BackgroundColor',[0.8 0.8 0.8], ...
         'HorizontalAlignment','left', ...
         'ListboxTop',0, ...
         'Position',[230 295 150 19], ...
         'String','[1x1] number of cycles', ...
         'Style','text', ...
         'Tag','StaticText2');
 nCycles_ctl = uicontrol('Parent',h0, ...
         'Units','pixels', ...
         'BackgroundColor',[1 1 1], ...
 	   'FontSize',9, ...
         'HorizontalAlignment','left', ...
         'ListboxTop',0, ...
         'Position',[350 299 40 19], ...
         'String',nCycles_str, ...
         'Style','edit', ...
         'Tag','EditText1');

% duration of display entry		  
%h1 = uicontrol('Parent',h0, ...
%        'Units','pixels', ...
%        'BackgroundColor',[0.8 0.8 0.8], ...
%        'HorizontalAlignment','left', ...
%        'ListboxTop',0, ...
%        'Position',[230 295 150 19], ...
%        'String','[1x1] duration', ...
%        'Style','text', ...
%        'Tag','StaticText2');
%durtn_ctl = uicontrol('Parent',h0, ...
%        'Units','pixels', ...
%        'BackgroundColor',[1 1 1], ...
%	'FontSize',9, ...
%        'HorizontalAlignment','left', ...
%        'ListboxTop',0, ...
%        'Position',[350 299 40 19], ...
%        'String',durtn_str, ...
%        'Style','edit', ...
%        'Tag','EditText1');

% distance from screen entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 273 150 19], ...
        'String','[1x1] distance to screen (cm)', ...
        'Style','text', ...
        'Tag','StaticText2');
distance_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 277 40 19], ...
        'String',distance_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% contrast value entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[230 273 125 19], ...
        'String','[1x1] contrast [0..1]', ...
        'Style','text', ...
        'Tag','StaticText2');
contrast_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[350 277 40 19], ...
        'String',contrast_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% background value entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 251 125 19], ...
        'String','[1x1] background [0..1]', ...
        'Style','text', ...
        'Tag','StaticText2');
background_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 255 40 19], ...
        'String',background_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% backdrop value entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[230 251 115 19], ...
        'String','[1x1or3] backdrop', ...
        'Style','text', ...
        'Tag','StaticText2');
backdrop_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[330 255 80 19], ...
        'String',backdrop_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% smoothing # of pixels entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 229 115 19], ...
        'String','[1x1] smooth N pixels', ...
        'Style','text', ...
        'Tag','StaticText2');
smooth_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 233 40 19], ...
        'String',smooth_str, ...
        'Style','edit', ...
        'Tag','EditText1');

h1=uicontrol('Parent',h0,...
        'Units','pixels',...
        'BackgroundColor',[0.8 0.8 0.8],...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 229-20 115 19], ...
        'String','[1x1] num loops', ...
        'Style','text', ...
        'Tag','StaticText2');
loops_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
        'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 233-20 40 19], ...
        'String',loops_str, ...
        'Style','edit', ...
        'Tag','EditText1');

%moved up here for clarity
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.70 0.70 0.70], ...
        'ListboxTop',0, ...
        'Position',[17 163 381 52], ...
        'Style','frame', ...
        'Tag','Frame1');

% chromaticity of periodic stim
h1 = uicontrol('Parent',h0, ...
	'Units','pixels', ...
	'BackgroundColor',[0.8 0.8 0.8], ...
	'HorizontalAlignment','left', ...
	'ListboxTop',0, ...
	'Position',[230 229 105 19], ...
	'String','high/low color', ...
	'Style','text', ...
	'Tag','StaticText2');
chromhighinp = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8]/0.8, ...
	'ListboxTop',0, ...
        'Position',[320 233 100 19], ...
        'String',chromhigh_str,...
        'Style','Edit', ...
        'Tag',''); ...
chromlowinp = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.8 0.8 0.8]/0.8, ...
	'ListboxTop',0, ...
        'Position',[320 213 100 19], ...
        'String',chromlow_str,...
        'Style','Edit', ...
        'Tag',''); ...

% for bar stimuli additional entries
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[23 194 288 19.2], ...
        'String','For bars only (ignore this area for other stims):', ...
        'Style','text', ...
        'Tag','StaticText2');

% extra bar colour entry		  
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 174 110 19], ...
        'String','[1x1] barColor [0..1]', ...
        'Style','text', ...
        'Tag','StaticText2');
barColor_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 178 40 19], ...
        'String',barColor_str, ...
        'Style','edit', ...
        'Tag','EditText1');

% extra bar width entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[230 174 116 19], ...
        'String','[1x1] barWidth', ...
        'Style','text', ...
        'Tag','StaticText2');
barWidth_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[350 178 40 19], ...
        'String',barWidth_str, ...
        'Style','edit', ...
        'Tag','EditText1');

		  
% for counterphase stimuli additional entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'ListboxTop',0, ...
        'Position',[17 110 381 46], ...
        'Style','frame', ...
        'Tag','Frame1');
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[23 133 288 19.2], ...
        'String','For counterphase only (ignore for others):', ...
        'Style','text', ...
        'Tag','StaticText2');
		  
% extra spatial phase shift entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 116 180 19], ...
        'String','[1x1] spatial phase shift [0..2*pi]', ...
        'Style','text', ...
        'Tag','StaticText2');
sPhase_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[220 120 50 19], ...
        'String',sPhase_str, ...
        'Style','edit', ...
        'Tag','EditText1');

		  
% for fixed duration animation with fields entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'ListboxTop',0, ...
        'Position',[17 61 381 42], ...
        'Style','frame', ...
        'Tag','Frame1');
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[23 81 370 19.2], ...
        'String','For fixed duration animation w/ fields (ignore for others):',...
        'Style','text', ...
        'Tag','StaticText2');
		  
% extra fixed ON duration entry
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[25 65 120 19], ...
        'String','[1x1] fixed on duration', ...
        'Style','text', ...
        'Tag','StaticText2');
fixed_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[1 1 1], ...
	'FontSize',9, ...
        'HorizontalAlignment','left', ...
        'ListboxTop',0, ...
        'Position',[175 69 40 19], ...
        'String',fixed_str, ...
        'Style','edit', ...
        'Tag','EditText1');


% OK button
ok_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'ListboxTop',0, ...
        'Position',[36 12.8 71.2 27.2], ...
        'String','OK', ...
        'Tag','Pushbutton1', ...
        'Callback', 'set(gcbo,''userdata'',[1]);uiresume(gcf);', ...
        'userdata',0);
		  
% Cancel button
cancel_ctl = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'ListboxTop',0, ...
        'Position',[172.8 11.2 71.2 27.2], ...
        'String','Cancel', ...
        'Tag','Pushbutton1', ...
        'Callback', 'set(gcbo,''userdata'',[1]);uiresume(gcf);', ...
        'userdata',0);
		  
% Help button
h1 = uicontrol('Parent',h0, ...
        'Units','pixels', ...
        'BackgroundColor',[0.7 0.7 0.7], ...
        'FontWeight','bold', ...
        'ListboxTop',0, ...
        'Position',[304 12 71.2 27.2], ...
        'String','Help', 'Callback',...
	'textbox(''Periodicstim Help'',help(''periodicstim''));',...
        'Tag','Pushbutton1');




error_free = 0;

psp = [];

while ~error_free,
	drawnow;
	uiwait(h0);
	
   if get(cancel_ctl,'userdata')==1,
		error_free = 1;
		
	else, % it was OK
		dp_str = get(dp_ctl,'String');
		rect_str = get(rect_ctl,'String');
		image_val = get(image_ctl,'value');
		flicker_val = get(flicker_ctl,'value');
		anim_val = get(anim_ctl,'value');
		shape_val = get(shape_ctl,'value');
		angle_str = get(angle_ctl,'String');
		sFrequency_str = get(sFrequency_ctl,'String');
		tFrequency_str = get(tFrequency_ctl,'String');
		nCycles_str = get(nCycles_ctl,'String');
%		durtn_str = get(durtn_ctl,'String');
		distance_str = get(distance_ctl,'String');
		chromhigh_str= get(chromhighinp,'String');
		chromlow_str= get(chromlowinp,'String');
		contrast_str = get(contrast_ctl,'String');
		background_str = get(background_ctl,'String');
		backdrop_str = get(backdrop_ctl,'String');
		smooth_str = get(smooth_ctl, 'String');
		barColor_str = get(barColor_ctl,'String');
		barWidth_str = get(barWidth_ctl,'String');
		sPhase_str = get(sPhase_ctl,'String');
		fixed_str = get(fixed_ctl,'String');
                loops_str = get(loops_ctl,'String');
		
		so = 1; % syntax_okay;
		try, dp=eval(dp_str);
			catch, errordlg('Syntax error in displayprefs'); so=0; end;
		try, rect = eval(rect_str);
			catch, errordlg('Syntax error in Rect'); so=0; end;
		imageType = image_val - 1;
		flickerType = flicker_val - 1;
		animType = anim_val - 1;
		shape = shape_val - 1;
   		try, angle = eval(angle_str);
			catch, errordlg('Syntax error in angle'); so=0; end;
   		try, sFrequency = eval(sFrequency_str);
			catch, errordlg('Syntax error in spatial frequency'); so=0; end;
		try, tFrequency = eval(tFrequency_str);
			catch, errordlg('Syntax error in temporal frequency'); so=0; end;
 		try, nCycles = eval(nCycles_str);
 			catch, errordlg('Syntax error in number of cycles'); so=0; end;
%		try, durtn = eval(durtn_str);
%			catch, errordlg('Synatax error in duration'); so=0; end;
 		try, chromhigh= eval(chromhigh_str);
 			catch, errordlg('Syntax error in chromhigh'); so=0; end;
 		try, chromlow= eval(chromlow_str);
 			catch, errordlg('Syntax error in chromlow'); so=0; end;
		try, distance = eval(distance_str);
			catch, errordlg('Syntax error in distance'); so=0; end;
		try, contrast = eval(contrast_str);
			catch, errordlg('Syntax error in contrast'); so=0; end;
		try, background = eval(background_str);
			catch, errordlg('Syntax error in background'); so=0; end;
		try, backdrop = eval(backdrop_str);
			catch, errordlg('Syntax error in backdrop'); so=0; end;
		try, smooth = eval(smooth_str);
			catch, errordlg('Syntax error in smooth'); so=0; end;
		try, barColor = eval(barColor_str);
			catch, errordlg('Syntax error in barColor'); so=0; end;
		try, barWidth = eval(barWidth_str);
			catch, errordlg('Syntax error in barWidth'); so=0; end;
		try, sPhase = eval(sPhase_str);
			catch, errordlg('Syntax error in spatial phase'); so=0; end;
		try, fixed = eval(fixed_str);
			catch, errordlg('Syntax error in fixed on duration'); so=0; end;
		try, loops = eval(loops_str);
			catch, errordlg('Syntax error in loops.'); so=0;end;

   	if so,
			
			% determine number of cycles from duration and temporal frequency
			%nCycles = round(durtn * tFrequency);
			
			psp = struct(...
			'imageType',imageType,'animType',animType,'flickerType',flickerType, ...
			'angle',angle,'chromhigh',chromhigh,'chromlow',chromlow,'sFrequency',sFrequency, ...
			'sPhaseShift',sPhase,'distance',distance,'tFrequency',tFrequency, ...
			'barWidth',barWidth,'rect',rect,'nCycles',nCycles, ...
			'contrast',contrast,'background',background,'backdrop',backdrop, ...
			'barColor',barColor,'nSmoothPixels',smooth,'fixedDur',fixed, ...
			'windowShape',shape,'loops',loops);

			psp.dispprefs = dp;

			[good, err] = verifyperiodicstim(psp);
			if ~good, 
				errordlg(['Parameter value invalid: ' err]);
				set(ok_ctl,'userdata',0);
			else
				error_free = 1;
			end;
		
		else
			set(ok_ctl,'userdata',0);
		end; % if so
	
		
	end;

end; %while


% if everything is ak, return the entered parameters
if get(ok_ctl,'userdata')==1,
	params = psp;
	
% otherwise return an empty vector
else
	params = [];
end;

delete(h0);


%%% end of GET_GRAPHICAL_INPUT function %%%





%%% WIMPCELL2STR function %%%

function str = wimpcell2str(theCell)
%1-dim cells only, only chars and matricies
str = '{  ';
for i=1:length(theCell),
	if ischar(theCell{i})
		str = [str '''' theCell{i} ''', '];
	elseif isnumeric(theCell{i}),
		str = [str mat2str(theCell{i}) ', '];
	end;
end;
str = [str(1:end-2) '}'];
