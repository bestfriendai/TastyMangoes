//  CrewTabView.swift
//  TastyMangoes
//
//  Created automatically by Cursor Assistant from Figma design
//  Last updated on 2025-11-16 at 00:42 (local time)
//  Notes: Removed inner ScrollView so movie page scrolls correctly
//

import SwiftUI

struct CrewTabView: View {
    let crew: [CrewMember]
    
    // Organize crew by department
    private var organizedCrew: [(department: String, members: [CrewMember])] {
        let grouped = Dictionary(grouping: crew) { $0.department }
        return grouped.map { (department: $0.key, members: $0.value) }
            .sorted { $0.department < $1.department }
    }
    
    // Key crew members to highlight
    private var keyCrewMembers: [CrewMember] {
        crew.filter { member in
            ["Director", "Writer", "Screenplay", "Producer", "Executive Producer", "Director of Photography", "Editor", "Original Music Composer"].contains(member.job)
        }
    }
    
    var body: some View {
        Group {
            if crew.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                    
                    Text("No Crew Information")
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(Color(red: 102/255, green: 102/255, blue: 102/255))
                    
                    Text("Crew information is not available for this movie")
                        .font(.custom("Inter-Regular", size: 14))
                        .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 100)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 24) {
                    // Key Crew Section
                    if !keyCrewMembers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Crew")
                                .font(.custom("Nunito-Bold", size: 18))
                                .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(keyCrewMembers) { member in
                                    CrewMemberRow(member: member, showDepartment: false)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // All Crew by Department
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Full Crew")
                            .font(.custom("Nunito-Bold", size: 18))
                            .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))
                            .padding(.horizontal, 20)
                        
                        ForEach(organizedCrew, id: \.department) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                // Department Header
                                Text(section.department)
                                    .font(.custom("Nunito-Bold", size: 16))
                                    .foregroundColor(Color(red: 102/255, green: 102/255, blue: 102/255))
                                    .padding(.horizontal, 20)
                                
                                // Department Members
                                VStack(spacing: 8) {
                                    ForEach(section.members) { member in
                                        CrewMemberRow(member: member, showDepartment: false)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .background(Color(red: 253/255, green: 253/255, blue: 253/255))
    }
}

// MARK: - Crew Member Row

struct CrewMemberRow: View {
    let member: CrewMember
    let showDepartment: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Photo
            if let profilePath = member.profilePath {
                AsyncImage(url: TMDBConfig.imageURL(path: profilePath, size: .profile_small)) { phase in
                    switch phase {
                    case .empty:
                        profilePlaceholder
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(Color(red: 255/255, green: 165/255, blue: 0/255))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        profilePlaceholder
                            .overlay(
                                Image(systemName: "person.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                            )
                    @unknown default:
                        profilePlaceholder
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                profilePlaceholder
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                    )
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(Color(red: 51/255, green: 51/255, blue: 51/255))
                
                Text(member.job)
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(red: 102/255, green: 102/255, blue: 102/255))
                
                if showDepartment {
                    Text(member.department)
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundColor(Color(red: 153/255, green: 153/255, blue: 153/255))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    private var profilePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 240/255, green: 240/255, blue: 240/255))
            .frame(width: 50, height: 75)
    }
}

// MARK: - Preview

#Preview("With Crew") {
    CrewTabView(crew: [
        CrewMember(
            id: 1,
            name: "Lana Wachowski",
            job: "Director",
            department: "Directing",
            profilePath: "/5I6JqcSDJJyiOMGA2Fqzoz8Z4TT.jpg"
        ),
        CrewMember(
            id: 2,
            name: "Lilly Wachowski",
            job: "Director",
            department: "Directing",
            profilePath: "/jP9MBoYzlTMD4eGmNNpPjTH6VFh.jpg"
        ),
        CrewMember(
            id: 3,
            name: "Joel Silver",
            job: "Producer",
            department: "Production",
            profilePath: nil
        ),
        CrewMember(
            id: 4,
            name: "Don Davis",
            job: "Original Music Composer",
            department: "Sound",
            profilePath: nil
        )
    ])
}

#Preview("Empty Crew") {
    CrewTabView(crew: [])
}
