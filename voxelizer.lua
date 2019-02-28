--Voxelizor v2 3/30/2014
wait(3)
local edge_threshold = 1.25
local corner_threshold = 0.61

local floor = math.floor
local abs = math.abs
local ceil = math.ceil
local max = math.max
local min = math.min
local instance = Instance.new
local vector = Vector3.new

local function get_normals(cframe)
	local 	x, y, z,
			r00, r01, r02,
			r10, r11, r12,
			r20, r21, r22
		= cframe:components()
	return 	vector(r00, r10, r20),
			vector(r01, r11, r21), 
			vector(r02, r12, r22)
end

local function get_points(pos, size, i, j, k)
	local x, y, z = size.x * i, size.y * j, size.z * k
	pos = pos + (x+y+z)* -0.5
	return {
		pos            ;
		pos         + z;
		pos     + y    ;
		pos     + y + z;
		pos + x        ;
		pos + x     + z;
		pos + x + y    ;
		pos + x + y + z;
	}
end

local function get_surfaces(part)
	local i, j, k = get_normals(part.CFrame)
	local p = get_points(part.Position, part.Size, i, j, k)
	--Clockwise looking at
	return {
		[k] = {p[8], p[4], p[2], p[6]}; --Front all positive z
		[i] = {p[8], p[6], p[5], p[7]}; --Right all positive x
		[j] = {p[8], p[7], p[3], p[4]}; --Top all positive y
		[-j]= {p[1], p[5], p[6], p[2]}; --Bottom all negative y
		[-i]= {p[1], p[2], p[4], p[3]}; --Left all negative x
		[-k]= {p[1], p[3], p[7], p[5]}; --Back all negative z
	}
end

--[[
x, y = known, z = solve. x could be y, y = z, and z = x. Whatever is
needed to voxelize the surface. The mathematical reason for
this is that one way could be dividing by zero, making an infinite
number of solutions and blowing up the world.
+------------------------------------------------------+
|**WARNING**: EXTREAM CODE AHEAD! PROCEED AT OWN PARIL!|
+------------------------------------------------------+
]]
local function voxelize_surface(n, surface, x, y, z)
	local p1 = surface[1]
	local p2 = surface[2]
	local p3 = surface[3]
	local p4 = surface[4]
	local function rotate_2d(v)
		local c = {
			[x] = -v[y];
			[y] = v[x];
			[z] = v[z];
		}
		return vector(c.x, c.y, c.z)
	end
	local v1 = rotate_2d(p2 - p1)
	local v2 = rotate_2d(p3 - p4)
	local v3 = rotate_2d(p3 - p2)
	local v4 = rotate_2d(p4 - p1)
	local function side(p, v, px, py)
		return (px - p[x]) * v[x] + (py - p[y]) * v[y]
	end
	local function is_plane(x, y)
		return 	side(p1, v1, x, y) * side(p4, v2, x, y) <= 0 and
				side(p2, v3, x, y) * side(p1, v4, x, y) <= 0
	end
	local function is_edge(p1, p2, p)
		local u = p - p1
		local v = p2 - p1
		local mag = u:Dot(v)/(v.x^2+v.y^2+v.z^2) --alpha of projection on the line
		if 1 > mag and mag > 0 then
			--Creates a triangle and solve for height for the distance to the line
			local d = (u):Cross(p - p2).magnitude/v.magnitude
			return d < edge_threshold
		end
	end
	local function is_corner(c, p)
		return (c-p).magnitude <= corner_threshold
	end
	local d = -n:Dot(p1)
	local s = n[z] < 0
	local function z_line(vx, vy)
		return (s and floor or ceil)((s and -0.25 or 0.25)-(d + n[y]*vy + n[x]*vx)/n[z])
	end
	
	local container = instance "Model"
	container.Parent = workspace
	local function absolute (vx, vy, vz)
		local c = {[x] = vx, [y] = vy, [z] = vz}
		return vector(c.x, c.y, c.z)
	end
	local function point(p)
		local part = instance "Part"
		part.Position = p
		part.FormFactor = "Custom"
		part.Anchored = true
		part.Size = vector(1, 1, 1)
		part.Parent = container
	end
	local min_y = floor(min(p1[y], p2[y], p3[y], p4[y]))
	local max_y = ceil(max(p1[y], p2[y], p3[y], p4[y]))
	for x = floor(min(p1[x], p2[x], p3[x], p4[x])), ceil(max(p1[x], p2[x], p3[x], p4[x])) do
		for y = min_y, max_y do
			local z = z_line(x, y)
			local p = absolute(x, y, z)
			if is_plane(x, y) or
				is_edge(p1, p2, p) or
				is_edge(p1, p4, p) or
				is_edge(p3, p2, p) or
				is_edge(p3, p4, p) or
				is_corner(p1, p) or
				is_corner(p2, p) or
				is_corner(p3, p) or
				is_corner(p4, p) then
				point(p)
			end
		end
	end
end

local function voxelize(part)
	local surfaces = get_surfaces(part)
	local points = {}
	for normal, surface in next, surfaces do
		local nx = abs(normal.x)
		local ny = abs(normal.y)
		local nz = abs(normal.z)
		if nx < ny then
			if nx < nz then
				if ny < nz then
					points[normal] = voxelize_surface(normal, surface, "x", "y", "z")
				else
					points[normal] = voxelize_surface(normal, surface, "x", "z", "y")
				end
			else
				points[normal] = voxelize_surface(normal, surface, "z", "x", "y")
			end
		elseif ny < nz then
			if nx < nz then
				points[normal] = voxelize_surface(normal, surface, "y", "x", "z")
			else
				points[normal] = voxelize_surface(normal, surface, "y", "z", "x")
			end
		else
			points[normal] = voxelize_surface(normal, surface, "z", "y", "x")
		end
	end
	return points
end

return {
	voxelize = voxelize;
}
