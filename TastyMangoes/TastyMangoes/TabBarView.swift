//
//  TabBarView.swift
//  TastyMangoes
//

import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarItem(
                icon: "house.fill",
                label: "Home",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            TabBarItem(
                icon: "magnifyingglass",
                label: "Search",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            TabBarItem(
                icon: "bookmark.fill",
                label: "Watchlist",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            TabBarItem(
                icon: "airplane",
                label: "Flight Mode",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
            
            TabBarItem(
                icon: "person.fill",
                label: "Profile",
                isSelected: selectedTab == 4
            ) {
                selectedTab = 4
            }
        }
        .frame(height: 80)
        .background(Color(red: 26/255, green: 26/255, blue: 26/255))
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(red: 196/255, green: 197/255, blue: 92/255) : Color(red: 128/255, green: 128/255, blue: 128/255))
                
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? Color(red: 196/255, green: 197/255, blue: 92/255) : Color(red: 128/255, green: 128/255, blue: 128/255))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    @Previewable @State var selectedTab = 1
    TabBarView(selectedTab: $selectedTab)
}
